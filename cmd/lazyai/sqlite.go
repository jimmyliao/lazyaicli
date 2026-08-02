package main

import (
	"encoding/binary"
	"errors"
	"os"
	"strings"
	"unicode"
	"unicode/utf8"
)

// sqliteRecords reads table-leaf records directly from an SQLite file. It is
// intentionally small: lazyai only needs read-only access to AGY's steps table,
// and shipping a full SQLite driver would add a dependency for this one query.
func sqliteRecords(path string) ([][]any, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(b) < 100 || string(b[:16]) != "SQLite format 3\x00" {
		return nil, errors.New("not an SQLite database")
	}
	pageSize := int(binary.BigEndian.Uint16(b[16:18]))
	if pageSize == 1 {
		pageSize = 65536
	}
	if pageSize < 512 {
		return nil, errors.New("invalid SQLite page size")
	}
	reserved := int(b[20])
	usable := pageSize - reserved
	var rows [][]any
	for pageStart := 0; pageStart < len(b); pageStart += pageSize {
		pageEnd := pageStart + pageSize
		if pageEnd > len(b) {
			pageEnd = len(b)
		}
		header := pageStart
		if pageStart == 0 {
			header += 100
		}
		if header+8 > pageEnd || b[header] != 0x0d {
			continue
		}
		count := int(binary.BigEndian.Uint16(b[header+3 : header+5]))
		for i := 0; i < count; i++ {
			pos := header + 8 + i*2
			if pos+2 > pageEnd {
				break
			}
			cell := pageStart + int(binary.BigEndian.Uint16(b[pos:pos+2]))
			if cell >= pageEnd {
				continue
			}
			payloadN, n1, ok := sqliteVarint(b, cell)
			if !ok {
				continue
			}
			_, n2, ok := sqliteVarint(b, cell+n1)
			if !ok {
				continue
			}
			payloadStart := cell + n1 + n2
			payload, ok := sqlitePayload(b, payloadStart, int(payloadN), pageSize, usable, pageEnd)
			if !ok {
				continue
			}
			if row, ok := sqliteRecord(payload); ok {
				rows = append(rows, row)
			}
		}
	}
	return rows, nil
}

func sqlitePayload(db []byte, start, total, pageSize, usable, pageEnd int) ([]byte, bool) {
	if total < 0 {
		return nil, false
	}
	maxLocal := usable - 35
	minLocal := ((usable - 12) * 32 / 255) - 23
	local := total
	if total > maxLocal {
		k := minLocal + ((total - minLocal) % (usable - 4))
		if k <= maxLocal {
			local = k
		} else {
			local = minLocal
		}
	}
	if start+local > pageEnd || start+local > len(db) {
		return nil, false
	}
	out := append([]byte(nil), db[start:start+local]...)
	if local == total {
		return out, true
	}
	if start+local+4 > pageEnd {
		return nil, false
	}
	next := int(binary.BigEndian.Uint32(db[start+local : start+local+4]))
	for len(out) < total && next > 0 {
		p := (next - 1) * pageSize
		if p+4 > len(db) {
			return nil, false
		}
		following := int(binary.BigEndian.Uint32(db[p : p+4]))
		take := usable - 4
		if take > total-len(out) {
			take = total - len(out)
		}
		if p+4+take > len(db) {
			return nil, false
		}
		out = append(out, db[p+4:p+4+take]...)
		next = following
	}
	return out, len(out) == total
}

func sqliteRecord(p []byte) ([]any, bool) {
	hsz, n, ok := sqliteVarint(p, 0)
	if !ok || int(hsz) > len(p) || int(hsz) < n {
		return nil, false
	}
	serials := []uint64{}
	at := n
	for at < int(hsz) {
		v, m, ok := sqliteVarint(p, at)
		if !ok {
			return nil, false
		}
		serials = append(serials, v)
		at += m
	}
	data := int(hsz)
	row := make([]any, 0, len(serials))
	for _, s := range serials {
		size := sqliteSerialSize(s)
		if data+size > len(p) {
			return nil, false
		}
		raw := p[data : data+size]
		data += size
		switch {
		case s == 0:
			row = append(row, nil)
		case s >= 1 && s <= 6:
			var v int64
			for _, x := range raw {
				v = (v << 8) | int64(x)
			}
			row = append(row, v)
		case s == 8:
			row = append(row, int64(0))
		case s == 9:
			row = append(row, int64(1))
		case s >= 12 && s%2 == 0:
			row = append(row, append([]byte(nil), raw...))
		case s >= 13 && s%2 == 1:
			row = append(row, string(raw))
		default:
			row = append(row, nil)
		}
	}
	return row, true
}
func sqliteSerialSize(s uint64) int {
	switch s {
	case 0, 8, 9, 10, 11:
		return 0
	case 1:
		return 1
	case 2:
		return 2
	case 3:
		return 3
	case 4:
		return 4
	case 5:
		return 6
	case 6, 7:
		return 8
	}
	if s >= 12 {
		return int((s - 12 - (s % 2)) / 2)
	}
	return 0
}
func sqliteVarint(b []byte, at int) (uint64, int, bool) {
	var v uint64
	for i := 0; i < 9 && at+i < len(b); i++ {
		x := b[at+i]
		if i == 8 {
			return (v << 8) | uint64(x), 9, true
		}
		v = (v << 7) | uint64(x&0x7f)
		if x < 0x80 {
			return v, i + 1, true
		}
	}
	return 0, 0, false
}

func agySQLiteTitle(path string) string {
	rows, err := sqliteRecords(path)
	if err != nil {
		return "conversation"
	}
	for _, row := range rows {
		// AGY steps currently have 11 columns: idx, step_type, ..., step_payload.
		if len(row) != 11 {
			continue
		}
		typ, ok := row[1].(int64)
		if !ok || typ != 14 {
			continue
		}
		payload, ok := row[9].([]byte)
		if !ok {
			continue
		}
		if title := agyUserInput(payload); title != "" {
			return title
		}
	}
	return "conversation"
}

func agyUserInput(payload []byte) string {
	var candidates []string
	protobufStrings(payload, 0, &candidates)
	for _, s := range candidates {
		if i := strings.Index(s, "</sender_context>"); i >= 0 {
			s = strings.TrimSpace(s[i+len("</sender_context>"):])
		}
		s = strings.Join(strings.Fields(s), " ")
		if len(s) == 0 || strings.HasPrefix(s, "<sender_context>") {
			continue
		}
		if strings.HasPrefix(s, "{") || strings.HasPrefix(s, "[") || strings.HasPrefix(s, "/") || strings.HasPrefix(s, "file:") {
			continue
		}
		letters := 0
		for _, r := range s {
			if unicode.IsLetter(r) {
				letters++
			}
		}
		if letters == 0 || isIdentifier(s) {
			continue
		}
		if len([]rune(s)) > 100 {
			s = string([]rune(s)[:100])
		}
		return s
	}
	return ""
}
func isIdentifier(s string) bool {
	if len(s) >= 30 && !strings.ContainsAny(s, " \t，。！？") {
		return true
	}
	return false
}

func protobufStrings(b []byte, depth int, out *[]string) {
	if depth > 8 {
		return
	}
	for i := 0; i < len(b); {
		key, n, ok := protobufVarint(b, i)
		if !ok {
			return
		}
		i += n
		switch key & 7 {
		case 0:
			_, n, ok = protobufVarint(b, i)
			if !ok {
				return
			}
			i += n
		case 1:
			i += 8
		case 5:
			i += 4
		case 2:
			var size uint64
			size, n, ok = protobufVarint(b, i)
			if !ok {
				return
			}
			i += n
			if size > uint64(len(b)-i) {
				return
			}
			part := b[i : i+int(size)]
			i += int(size)
			if utf8.Valid(part) {
				s := string(part)
				printable := 0
				for _, r := range s {
					if unicode.IsPrint(r) || unicode.IsSpace(r) {
						printable++
					}
				}
				if len([]rune(s)) > 0 && printable*10 >= len([]rune(s))*9 {
					*out = append(*out, s)
				}
			}
			protobufStrings(part, depth+1, out)
		default:
			return
		}
		if i > len(b) {
			return
		}
	}
}
func protobufVarint(b []byte, at int) (uint64, int, bool) {
	var v uint64
	for i := 0; i < 10 && at+i < len(b); i++ {
		x := b[at+i]
		v |= uint64(x&0x7f) << uint(7*i)
		if x < 0x80 {
			return v, i + 1, true
		}
	}
	return 0, 0, false
}
