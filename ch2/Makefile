
all:
	rm -f mbr.bin
	rm -f c.img
	nasm -f bin mbr.s -o mbr.bin
	dd if=/dev/zero of=c.img count=10000
	dd if=mbr.bin of=c.img bs=512 count=1 conv=notrunc

clean:
	rm -f bochsout.txt
	rm -f mbr.bin
	rm -f c.img