PREFIX = /usr/local
CFLAGS += $(shell pkg-config --cflags openssl) --std=c99
LDFLAGS += $(shell pkg-config --libs-only-L openssl)
LDLIBS += $(shell pkg-config --libs-only-l openssl)

.PHONY: all
all: server

.PHONY: install
install: server
	install -Dm755 $< $(PREFIX)/bin/$<

.PHONY: clean
clean:
	$(RM) *.o server

server: server.o
