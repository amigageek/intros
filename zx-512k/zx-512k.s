	; ZX 512K by djay for Lovebyte 22
	;
	; A 512 byte bootblock intro for Amiga
	; Requires Kickstart 1.2 or 1.3
	;
	; Stripped down concept of an unreleased 4K
	; which ran on both Amiga and (via its audio)
	; ZX Spectrum.

_LVOAllocMem		= -$C6
AUD0DAT			= $AA
AUD0PER			= $A6
AUD0VOL			= $A8
AUD1DAT			= $BA
AUD1PER			= $B6
AUD1VOL			= $B8
BPLCON0			= $100
BPLCON0_BPUX_SHF	= $C
BPLCON0_COLOR		= $200
BPL4PTH			= $EC
COLOR00			= $180
COLOR04			= $188
COLOR06			= $18C
COLOR12			= $198
COLOR14			= $19C
CUSTOM			= $DFF000
DDFSTRT			= $92
DIWSTRT			= $8E
DIWSTRT_V0_SHF		= $8
DIWSTOP_V0_SHF		= $8
DMACON			= $96
DMACON_DMAEN		= $200
DMACON_BPLEN		= $100
DMACON_INTENA_INTREQ_CLEARALL	= $7FFF
DMACON_SETCLR		= $8000
INT_AUD0		= $1<<$7
INT_AUD1		= $1<<$8
INT_VERTB		= $1<<$5
INTENA			= $9A
INTREQ			= $9C
INTREQR			= $1E
MEMF_CHIP		= $2
MEMF_CLEAR		= $10000

ROM_DRAW_KICK_13	= $FE8732		; Address of ROM drawing routine in Kickstart 1.3
ROM_DRAW_FIRST_BYTE	= $43			; First byte of ROM drawing routine
ROM_DRAW_KICK_12_OFF	= $44C			; Offset from Kickstart 1.3 to 1.2 ROM routine
ROM_DRAW_BPLS_A5_OFF	= $20			; Offset from a5 to bitplanes address after ROM routine
ROM_BPL_WIDTH		= $140
ROM_BPL_HEIGHT		= $C8			; NTSC height
ROM_BPL_SHIFT_X		= $10			; Horizontal shift to center image in ZX screen
ROM_BPL_SHIFT_Y		= $13			; Vertical shift to center image in ZX screen
ROM_BPL_STRIDE		= ROM_BPL_WIDTH/$8
ROM_BPL_SLICE		= ROM_BPL_STRIDE*ROM_BPL_HEIGHT
ROM_BPL_SHIFT		= (ROM_BPL_SHIFT_Y*ROM_BPL_STRIDE)+(ROM_BPL_SHIFT_X/$8)
DISP_WIDTH		= $100			; ZX resolution
DISP_HEIGHT		= $C0
DISP_DEPTH		= $4			; For palette tricks
DISP_SLICE		= DISP_WIDTH*DISP_HEIGHT/$8
DISP_SIZE		= DISP_SLICE*DISP_DEPTH
DISP_WIN_X		= $A1			; Centered ZX screen
DISP_WIN_Y		= $4C
DISP_RES		= $8 ; $8 = lores, $4 = hires
DISP_FETCH_X		= DISP_WIN_X
DIWSTRT_VAL		= (DISP_WIN_Y<<DIWSTRT_V0_SHF)|DISP_WIN_X
DIWSTOP_VAL		= ((DISP_WIN_Y+DISP_HEIGHT-$100)<<DIWSTOP_V0_SHF)|(DISP_WIN_X+DISP_WIDTH-$100)
DDFSTRT_VAL		= (DISP_FETCH_X/$2)-DISP_RES
DDFSTOP_VAL		= (DISP_FETCH_X/$2)-DISP_RES+($8*((DISP_WIDTH/$10)-$1))
SILENT_CYCLES		= $327			; 1 second at leader period
LEADER_PERIOD		= $225			; 2168*2 cycles at 3.5MHz, 8 samples per cycle
LEADER_HEADER_CYCLES	= $FC0			; 8063 edges
LEADER_DATA_CYCLES	= $64C			; 3223 edges
HEADER_CYCLES		= $13*$8		; 19 characters in ZX header
DATA_PERIOD		= $1B1			; 855*2 cycles at 3.5MHz, 4 samples per cycle

	; Invoke the ROM boot screen drawing subroutine
	; Inputs:
	;	a5: Somewhere to write
	;	(a5): SysBase
	; Outputs:
	;	(a5,$20): Base address of bitplanes
	;	LoadView has been called but bitplane DMA is disabled
	movea.l	a7,a5				; Let subroutine trash the stack
	move.l	a6,(a5)				; ExecBase
	lea	ROM_DRAW_KICK_13.l,a0
	cmpi.b	#ROM_DRAW_FIRST_BYTE,(a0)
	beq.b	found_rom_draw
	lea	(ROM_DRAW_KICK_12_OFF,a0),a0	; If not Kickstart 1.3 then assume 1.2
found_rom_draw:
	jsr	(a0)
	movea.l	(ROM_DRAW_BPLS_A5_OFF,a5),a4	; Base address of drawn bitplanes
	lea	(ROM_BPL_SHIFT,a4),a4		; Center the image for our 256x192 display

	; Allocate display bitplanes and fill bitplanes 0 and 1 (displayed in reverse order)
 	move.w	#DISP_SIZE,d0			; d0[31:16] = 0 from ROM routine
 	move.l	#(MEMF_CHIP|MEMF_CLEAR),d1
 	jsr	(_LVOAllocMem,a6)
 	movea.l	d0,a6
	move.w	#(DISP_SLICE*$2-$1),d1
 fill_bpls_loop:
 	st	(a6,d1.w)
 	dbf	d1,fill_bpls_loop

	; Switch off interrupts/DMA and program static custom chip state
 	lea	CUSTOM.l,a5
 	move.w	#(DMACON_INTENA_INTREQ_CLEARALL),d0
 	move.w	d0,(INTENA,a5)
	move.w	d0,(DMACON,a5)
 	move.l	#((DIWSTRT_VAL<<$10)|DIWSTOP_VAL),(DIWSTRT,a5)
 	move.l	#((DDFSTRT_VAL<<$10)|DDFSTOP_VAL),(DDFSTRT,a5)
 	move.w	#((DISP_DEPTH<<BPLCON0_BPUX_SHF)|BPLCON0_COLOR),(BPLCON0,a5)

	; Colors 12-15 are shown initially (bitplanes 2 and 3 set to 1)
	;	12 = white, 13-15 = black (for colorless image)
	;
	; Colors 4-7 are used during color phase (bitplane 3 is cleared)
	;	4 = white, 5 = black, 6 = blue, 7 = grey (Kickstart image colors)
	;
	; Color 0 is reserved for color bars outside bitplanes
	move.l	#$0FFF0000,(COLOR04,a5)
	move.l	#$077C0BBB,(COLOR06,a5)
	move.l	#$0BBB0000,(COLOR12,a5)
	clr.l	(COLOR14,a5)

	; Phase progression: silent, leader, header, silent, leader, data, end
 	lea	(phase_silent,pc),a3
phase_loop:
	moveq	#$0,d7				; d7 = consumed bit count
 	jsr	(a3)				; Phase init routine

	; One iteration per bit of data (or audio cycle) in this phase
bit_loop:
	; Check if vertical blank interrupt fired
	moveq	#INT_VERTB,d0
	and.w	(INTREQR,a5),d0
	beq.b	next_bit
	move.w	d0,(INTREQ,a5)

	; Enable bitplane DMA late to avoid artifacts
 	move.w	#(DMACON_SETCLR|DMACON_DMAEN|DMACON_BPLEN),(DMACON,a5)

	; Reset bitplane pointers. The order is reversed with respect to memory
	lea	(BPL4PTH+$4,a5),a0		; +4 for pre-decrement below
	movea.l	a6,a1
	moveq	#(DISP_DEPTH-$1),d0
program_bpl_loop:
	move.l	a1,-(a0)
	lea	(DISP_SLICE,a1),a1
	dbf	d0,program_bpl_loop

next_bit:
	moveq	#$7,d3
	and.b	d6,d3				; 7,6,5,4,3,2,1,0,7,6,5,...
	jsr	(a2)				; Get next bit
	bsr.b	output_sample			; High phase of square wave
	bsr.b	output_sample			; Low phase of square wave
	addq.w	#$1,d7				; ++ consumed bit count
	dbf	d6,bit_loop			; Repeat for next bit of data
	bra.b	phase_loop			; Move to next phase

	; Silent phase between activity
phase_silent:
	move.w	#LEADER_PERIOD,d0		; Silent but timed on audio interrupt
	bsr.b	set_audio_period
	move.l	#$7F7F7F7F,d4			; DC during silent phase
	move.l	#$0BBB0BBB,d5			; White border
	move.w	#(SILENT_CYCLES-$1),d6
	lea	(data_constant,pc),a2
	lea	(phase_leader,pc),a3
	rts

	; Sync tone with cyan border, then cyan/yellow bars after delay
phase_leader:
	moveq	#$10,d0				; -16 dB (squares are loud!)
	move.w	d0,(AUD0VOL,a5)			; Only change this while DC is output
	move.w	d0,(AUD1VOL,a5)
	move.w	#$8080,d4			; $7F7F8080 = square wave with 4 cycle period
	move.l	#$00BB00BB,d5			; Cyan/cyan
	move.w	#(LEADER_HEADER_CYCLES-$1),d6
	lea	(phase_header,pc),a3
	bchg.b	#$7,(a7)			; 1st: header data, 2nd: screen data
	beq.b	not_data_block
	move.w	#(LEADER_DATA_CYCLES-$1),d6
	lea	(phase_screen,pc),a3
not_data_block:
	lea	(data_leader,pc),a2
	rts

	; Alternates audio output (high/low) for one (bit=0) or two (bit=1) intervals
	; Alternates color bars once
	; Intervals timed on programmed audio period
output_sample:
	swap	d4				; Alternate high/low (or DC if constant)
	move.w	d4,(AUD0DAT,a5)
	move.w	d4,(AUD1DAT,a5)
	moveq	#($2-$1),d1
	btst.l	d3,d2
	beq.b	only_one_sample			; 0 => 1 sample (short), 1 => 2 samples (long)
clear_audio_int:
	move.w	#(INT_AUD0|INT_AUD1),(INTREQ,a5)
wait_audio_int:
	move.w	#(INT_AUD0|INT_AUD1),d0
	and.w	(INTREQR,a5),d0
	cmpi.w	#(INT_AUD0|INT_AUD1),d0
	bne.b	wait_audio_int
only_one_sample:
	dbf	d1,clear_audio_int
	move.w	d5,(COLOR00,a5)			; Alternate color bars on pulse edge
	swap	d5
	rts

set_audio_period:
	move.w	d0,(AUD0PER,a5)
	move.w	d0,(AUD1PER,a5)
	rts

	; Random data for block header, yellow/blue bars
phase_header:
	bsr.b	phase_screen			; Share a bunch of setup
	move.w	#(HEADER_CYCLES-$1),d6
	lea	(phase_silent,pc),a3
	lea	(data_header,pc),a2
	rts

	; Screen bitmap data then color data, yellow/blue bars
phase_screen:
	move.w	#DATA_PERIOD,d0
	bsr.b	set_audio_period
	move.l	#$0BB0000B,d5			; Yellow/blue
	move.w	#(DISP_SLICE*$9-$1),d6		; Screen data (1 bit per bit) + color data (1 bit per byte)
	lea	(phase_end,pc),a3
	lea	(data_screen,pc),a2
not_screen_data:
	rts

data_leader:
	cmpi.w	#SILENT_CYCLES,d7		; Wait 1 second before changing border colors
	bne.b	data_constant
	move.w	#$0B00,d5			; Cyan/yellow
data_constant:
	st	d2				; Long pulses, leader sample rate is 2x required
	rts

data_header:
	move.b	(a7,d7.w),d2			; 1 byte of stack data per bit of fake output :D
	rts

data_screen:
	move.l	d7,d0				; Consumed bit count
	move.w	d0,d1
	subi.w	#(DISP_SLICE*$8),d1		; End of bitmap data?
	bhs.b	data_color

	andi.b	#$7,d1				; First bit of byte?
	bne.b	have_screen_byte

 	; Convert ZX screen address to bitplane offset
 	ror.l	#$8,d0				; X7 X6 X5 X4 X3 xx xx xx ... 00 00 00 00 00 || Y7 Y6 Y2 Y1 Y0 Y5 Y4 Y3
 	lsl.w	#$2,d0				; X7 X6 X5 X4 X3 xx xx xx ... 00 00 00 Y7 Y6 || Y2 Y1 Y0 Y5 Y4 Y3 00 00
 	rol.b	#$3,d0				; X7 X6 X5 X4 X3 xx xx xx ... 00 00 00 Y7 Y6 || Y5 Y4 Y3 00 00 Y2 Y1 Y0
 	ror.l	#$3,d0				; Y2 Y1 Y0 X7 X6 X5 X4 X3 ... 00 00 00 00 00 || 00 Y7 Y6 Y5 Y4 Y3 00 00
 	lsr.b	#$2,d0				; Y2 Y1 Y0 X7 X6 X5 X4 X3 ... 00 00 00 00 00 || 00 00 00 Y7 Y6 Y5 Y4 Y3
 	rol.l	#$8,d0				; xx xx xx 00 00 00 00 00 ... Y7 Y6 Y5 Y4 Y3 || Y2 Y1 Y0 X7 X6 X5 X4 X3

 	lea	(a6,d0.w),a0			; Byte address in top display bitplane
	move.w	d0,d1
	andi.w	#$1F,d0				; X / $8
	lsr.w	#$5,d1				; Y
	mulu.w	#ROM_BPL_STRIDE,d1
	add.w	d1,d0
	lea	(a4,d0.w),a1			; Byte address in ROM drawn bitplane

	move.b	(a1),d2				; 8 pixels of ROM drawn bitplane 0
	move.b	d2,(DISP_SLICE*3,a0)		; Copy to bitplane 0 (reverse of display order)
	move.b	(ROM_BPL_SLICE,a1),d0		; 8 pixels of ROM drawn bitplane 1
	move.b	d0,(DISP_SLICE*2,a0)		; Copy to bitplane 1
	or.b	d0,d2				; Long audio pulse if either bitplane is set
have_screen_byte:
	rts

data_color:
	ror.b	#$3,d1				; Low 3 bits to high, for one line of 8x8 block per iteration
	clr.b	(a6,d1.w)			; Clear 8 pixels in bitplane 3 to reveal final color
	andi.b	#$7,d0				; First bit of byte?
	bne.b	have_color_byte
	addi.w	#(DISP_SLICE*3),d1		; Bitplane 0
	moveq	#$7,d2
	and.b	(a6,d1.w),d2			; Pretend color from 3 pixels on/off :)
	ori.b	#$78,d2				; Pretend ZX attribute data
have_color_byte:
	rts

phase_end:
	moveq	#$0,d4				; Zero DC audio
	moveq	#-$1,d5				; Repeat phase indefinitely
	lea	(data_constant,pc),a2		; No-op, stop changing image
	rts
