GLOBAL	printUnsignedInteger:PROC, \
		printBoard:PROC,\
		getOffset:PROC, \
		getElement:PROC, \
		getMovementElem:PROC, \
		clearMovement:PROC, \
		moveElement:PROC, \
		checkRookMovement:PROC, \
		checkBishopMovement:PROC, \
		checkKnightMovement:PROC, \
		checkKingMovement:PROC, \
		checkPawnMovement:PROC, \
		generatePieceMoves:PROC, \
		filterLegalMoves:PROC, \
		getGameStatus:PROC, \
		initializeDrawTracking:PROC, \
		recordPosition:PROC, \
		getDrawStatus:PROC, \
		promotePawn:PROC
		
GLOBAL board:BYTE
GLOBAL movement:BYTE
GLOBAL checked_king_row:DWORD, checked_king_col:DWORD
GLOBAL halfmove_clock:DWORD