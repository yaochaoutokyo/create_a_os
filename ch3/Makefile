
all:clean
	nasm -I include -o mbr.bin mbr.s
	nasm -I include -o loader.bin loader.s 
	dd if=/dev/zero of=c.img count=10000
	dd if=mbr.bin of=c.img bs=512 count=1 conv=notrunc
	dd if=loader.bin of=c.img bs=512 count=1 seek=2 conv=notrunc

clean:
	rm -f bochsout.txt
	rm -f mbr.bin
	rm -f loader.bin
	rm -f c.img