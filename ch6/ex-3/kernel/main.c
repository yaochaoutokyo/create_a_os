#include "print.h"
int main(void) {
	put_str("Hi! I am Kernel\n");
	put_str("This message is print by self-made lib\n");
	put_str("My entry address is:");
	put_int(0xc0001500);
	while(1);
}
