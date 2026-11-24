GLOBAL	setVideoMode:PROC, \
		terminateProcess:PROC, \
		draw_board:PROC, \
		draw_move_highlight:PROC, \
		draw_check_highlight:PROC, \
		draw_promotion_menu:PROC

EXTRN empty_sprite:BYTE, king_sprite:BYTE, pawn_sprite:BYTE, rook_sprite:BYTE, knight_sprite:BYTE, bishop_sprite:BYTE, queen_sprite:BYTE
