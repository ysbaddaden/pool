.POSIX:

CRYSTAL = crystal
CRFLAGS =
ARGS = --verbose

test: .phony
	$(CRYSTAL) run $(CRFLAGS) test/*_test.cr -- $(ARGS)

.phony:
