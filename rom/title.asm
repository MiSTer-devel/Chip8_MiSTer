TOTAL_STARS: EQU 30

	SECTION	"Title",CODE[$200]

Start:
	high
	cls

	call	CreateStars

CycleStars:
	ld		v14,0
	ld		v13,1
.loop
	ld		dt,v13
	ld		i,Stars
	add		i,v14
	ldm		v1,(i)
	ld		i,StarSprite
	drw		v0,v1,1
	rnd		v0,127
	rnd		v1,63
	drw		v0,v1,1
	ld		i,Stars
	add		i,v14
	ldm		(i),v1

	add		v14,2
	sne		v14,TOTAL_STARS*2
	ld		v14,0

.wait
	ld		v0,dt
	se		v0,0
	jp		.wait

	jp		.loop

CreateStars:
	ld		v14,0
	ld		v2,2
.loop
	rnd		v0,127
	rnd		v1,63
	ld		i,Stars
	add		i,v14
	ldm		(i),v1

	ld		i,StarSprite
	drw		v0,v1,1

	add		v14,2
	se		v14,TOTAL_STARS*2
	jp		.loop
	ret

StarSprite:
	DB		$80

	SECTION "Vars",BSS
Stars:
	DSB	2*TOTAL_STARS
