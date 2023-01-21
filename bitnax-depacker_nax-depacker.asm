// ---------------------------------------------------------------------------------
//  DECRUNCHER
// ---------------------------------------------------------------------------------
.const zp_base  = 8
.const lz_bits	= zp_base + 1
.const lz_dst	= zp_base + 2
.const lz_end	= zp_base + 4
.const lz_tmp	= zp_base + 6


// A = low byte
// Y = high byte
depack:
	sta ptr1
	sta ptr2
	sty ptr1 + 1
	sty ptr2 + 1
	ldx #$00
 
lz_decrunch:
		jsr lz_refill_bits      // fetch depack addr and depack end address
		sty lz_dst-1,x		    // -1 because x was already increased in lz_refill_bits
		cpx #$04
		bne lz_decrunch
		// sec                  // set for free by last compare
lz_type_refill:
		jsr lz_refill_bits      // refill bit buffer lz_bits
						        // called only once per depack with X = 2 or 4

// ******** Start the next match/literal run ********
lz_type_check:
		bcc lz_do_match
		beq lz_type_refill		// we will fall through on entry

// ******** Process literal run ********

		lda #$00
lz_literal_loop:                // Fetch copy length in bit pairs (control, data)
		rol				        // shift data bit into a (a = $01 after first round)
		asl lz_bits             // get top bit from lz_bits
		bne !+                  // fetch more bits if lz_bits became empty
		jsr lz_refill_bits		// kills y
!:		bcc lz_lrun_gotten      // control bit 0 -> done fetching

		asl lz_bits             // get data bit
		bne lz_literal_loop     // not empty -> loop around
		jsr lz_refill_bits      // otherwise get more bits 
		bne lz_literal_loop     // and loop

lz_lrun_gotten:
		sta lz_lcopy_len		// Store LSB of run-length
		ldy #$00

lz_lcopy:                       // Copy the literal data, forward or overlap 
                                // is getting a pain in the ass.
//.var bitfire_lz_sector_ptr2	= * + 1			
		lda ptr2: $beef,x
		sta (lz_dst),y
		inx
		bne !+
		jsr lz_next_page
!:
		iny 
		cpy lz_lcopy_len: #$00
		bne lz_lcopy

		tya
		beq lz_maximum			// maximum literal run, bump sector pointers and so on and force new type bit
		clc
		adc lz_dst
		sta lz_dst
		bcc lz_do_match
		inc lz_dst+1
						// no need for a type bit, after each literal a match follows, except for maximum runlength literals

// ******** Process match ********
lz_do_match:
		lda #$01			// this could be made shorter by using the last bitfetch of the upcoming loop and restoring the carry again by a cmp #$02. Saves bytes, but makes things slower, as eof check is also done with all short matches then
		asl lz_bits			// first length bit (where a one identifies
		bne !+				// a two-byte match)
		jsr lz_refill_bits
!:		bcc lz_get_offs		// all done, length is 2, skip further bitfetches (and eof check)

lz_do_match_lp:
		asl lz_bits
		bne !+
		jsr lz_refill_bits
!:		rol

		asl lz_bits
		bne !+
		jsr lz_refill_bits
!:		bcc lz_do_match_lp
lz_got_len:
		tay				        // XXX TODO could this be placed elsewhere to make the tay obsolete?
		bne lz_get_offs		// A 257-byte (=>$00) run serves as a sentinel, but not with zero-overlap, except when depacking from a non inplace address, then it is still appended
		rts
lz_get_offs:
		sta lz_mcopy_len		// store length at final destination
		lda #%11000000			// fetch 2 more prefix bits
		rol				        // previous bit is still in carry \o/
!l:
		asl lz_bits
		bne !+
		jsr lz_refill_bits
!:		rol
		bcs !l-

		beq lz_8_and_more		// 0 + 8 bits to fetch, branch out before table lookup to save a few cycles and one byte in the table, also save complexity on the bitfetcher
		tay
		lda lz_lentab,y
!:						        // same as above
		asl lz_bits			    // XXX same code as above, so annoying :-(
		bne *+5
		jsr lz_refill_bits
		rol
		bcs !-

		bmi lz_less_than_8		// either 3,4,6 or 7 bits fetched -> highbyte will be $ff
lz_8_and_more:
		jsr lz_refill_bits
		eor #$ff			    // 5 of 13, 2 of 10, 0 of 8 bits fetched as highbyte, lowbyte still to be fetched
		sta lz_tmp			    // XXX this is a pain in the arse that A and Y need to be swapped :-(
		tya
		ldy lz_tmp
		.byte $0c               // long nop, to skip the next ldys
lz_less_than_8:
		ldy #$ff			    // XXX TODO silly, y is set twice in short case
		adc lz_dst			    // subtract offset from lz_dst
		sta lz_m+1
		tya				        // hibyte
		adc lz_dst+1
		sta lz_m+2

		ldy #$ff			    // The copy loop. This needs to be run
						        // forwards since RLE-style matches can overlap the destination
lz_mcopy:
		iny
lz_m:
		lda $face,y			// copy one byte
		sta (lz_dst),y
		cpy lz_mcopy_len: #$ff
		bne lz_mcopy

		tya				// advance destination pointer
// 		sec				// XXX TODO carry set = type check needed, cleared (literal) = match follows anyway
		adc lz_dst
		sta lz_dst


		bcc !+				// proceed to check
lz_maximum:
		inc lz_dst+1		// advance hi byte
// 		lda lz_dst			// if entering via lz_maximum, a = 0, so we would pass the following check only if the endadress is @ $xx00
!:						    // if so, the endaddress can't be $xx00 and the highbyte check will fail, as we just successfully wrote a literal with type bit, so the end address must be greater then the current lz_dst, as either another literal or match must follow. Can you still follow me?! :-D
		eor lz_end			// check end address
lz_skip_poll:
    	bne lz_skip_end		// all okay, poll for a new block

		eor lz_dst+1		// check highbyte
		eor lz_end+1
		bne lz_skip_end		// skip poll, so that only one branch needs to be manipulated
		// sta .barrier		// clear barrier and force to load until EOF, XXX does not work, but will at least force one additional block before leaving as barrier will be set again upon next block being fetched. Will overlap be > than 2 blocks? most likely not? CRAP, tony taught me that there is /o\
		lda #$ff
		sta lz_refill_bits+2	// needed if the barrier method will not work out, plain jump to poll loop will fail on stand alone depack?
		rts					// load any remaining literal blob if there, or exit with rts in case of plain decomp (rts there instead of php). So we are forced until either the sector_ptr reaches $00xx or EOF happens, so nothing can go wrong
							// XXX TODO could be beq lz_next_page_ but we get into trouble with 2nd nmi gap then :-(

lz_skip_end:
						// literals needing an explicit type bit
		asl lz_bits			// fetch next type bit
		jmp lz_type_check
						// XXX TODO refill_bits -> do no shifting yet, but do in code, so we could reuse the asl ?!
	// endif DECOMP

// ---------------------------------------------------------------------------------
//  OFFSET TABLES
// ---------------------------------------------------------------------------------

lz_lentab:
		// short offset init values
		.byte %00000000			// 2
		.byte %11011111			// 0
		.byte %11111011			// 1
		.byte %10000000			// 3

		// long offset init values
		.byte %11101111			// offset 0
		.byte %11111101			// offset 1
		.byte %10000000			// offset 2
		.byte %11110000			// offset 3

lz_refill_bits:
		ldy ptr1: $beef,x
						    // store bits? happens on all calls, except when a whole literal is fetched
		bcc !+				// only store lz_bits if carry is set (in all cases, except when literal is fetched for offset)
		sty lz_bits
		rol lz_bits
!:
		inx
		bne !+

lz_next_page:					// /!\ ATTENTION things entered here as well during depacking
		inc lz_refill_bits + 2	// use inc to keep A untouched!
		inc lz_lcopy + 2	// Z flag should never be set, except when this wraps around to $00, but then one would need to load until $ffff?
!:		rts				// turned into a rts in case of standalone decomp


