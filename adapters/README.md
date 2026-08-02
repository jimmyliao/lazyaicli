# Backend adapters

Adapters are compiled into the self-contained `lazyai` executable.

Each adapter implements four responsibilities:

1. discover the backend's local session store;
2. emit normalized session metadata (`id`, title, cwd, modification time);
3. define the backend resume command;
4. honor the common list, number, id-prefix, and keyword selection contract.

Implementations live in `cmd/lazyai`. New adapters must not add user runtime dependencies. Build-time Go modules require explicit discussion before inclusion.
