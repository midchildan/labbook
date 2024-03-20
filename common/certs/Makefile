.PHONY: all
all: localhost.crt

.PHONY: clean
clean:
	$(RM) *.crt *.key

%.crt: %.cnf
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -sha256 \
 		-keyout $(<:.cnf=.key) -out $@ -config $<
