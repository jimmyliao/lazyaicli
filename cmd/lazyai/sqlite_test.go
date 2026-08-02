package main

import "testing"

func TestAgyUserInputAfterSenderContext(t *testing.T) {
	input := `<sender_context>{"channel":"discord"}</sender_context> 請修正 AGY session picker`
	payload := append([]byte{0x0a, byte(len(input))}, []byte(input)...)
	if got := agyUserInput(payload); got != "請修正 AGY session picker" {
		t.Fatalf("got %q", got)
	}
}

func TestSQLiteVarint(t *testing.T) {
	got, n, ok := sqliteVarint([]byte{0x81, 0x01}, 0)
	if !ok || n != 2 || got != 129 {
		t.Fatalf("got %d, %d, %v", got, n, ok)
	}
}
