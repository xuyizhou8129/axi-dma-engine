CC      ?= clang
CFLAGS  := -std=c99 -Wall -Wextra -O0 -g -I./include -I..

OUT := test_runner

.PHONY: all build run clean

all: run

# Compile firmware separately with main renamed so the test driver keeps its own main.
firmware.o: ../uart_read_write.c
	$(CC) $(CFLAGS) -Dmain=firmware_main -c $< -o $@

mocks.o: mocks.c
	$(CC) $(CFLAGS) -c $< -o $@

test_uart_read_write.o: test_uart_read_write.c
	$(CC) $(CFLAGS) -c $< -o $@

build: firmware.o mocks.o test_uart_read_write.o
	$(CC) -o $(OUT) firmware.o mocks.o test_uart_read_write.o

run: build
	./$(OUT)

clean:
	rm -f $(OUT) *.o
