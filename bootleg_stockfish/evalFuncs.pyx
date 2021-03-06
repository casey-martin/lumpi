'''TODO:
- pieceValueMg
    
- p_sqtMg
- pieceValueMg
- psqtMg
- imbalanceTotal
- pawnsMg
- piecesMg
- mobilityMg
- threatsMg
- passedMg
- space
- kingMg
'''
pos = {# chessboard
       'b': [["r","-","-","p","-","-","P","R"],
           ["n","p","-","-","-","-","P","N"],
           ["b","p","-","-","-","-","P","B"],
           ["q","p","-","-","-","-","P","Q"],
           ["k","p","-","-","-","-","-","K"],
           ["b","-","-","-","p","-","P","B"],
           ["-","P","-","-","P","-","-","N"],
           ["r","p","-","-","-","-","P","R"]], 
       # castling rights
       'c': [True,True,True,True],

       # enpassant
       'e': None,

       # side to move
       'w': False,

       # move counts
       'm': [0,4]}

##### Global Functions #####
def sfBoard(pos, x, y):
    if x >= 0 and x <=7 and y >= 0 and y <= 7:
        return(pos['b'][x][y])
    return('x')

def colorflip(pos):
    board = [['-'] * 8 for i in range(8)] 
    for x in range(8):
        for y in range(8):
            board[x][y] = pos['b'][x][7-y]
            color = board[x][y].upper() == board[x][y]
            if color:
                board[x][y] = board[x][y].lower()
            else:
                board[x][y] = board[x][y].upper()
    outPos = {'b':board, 'c':[pos['c'][2], pos['c'][3], pos['c'][0], pos['c'][1]],
              'w':not pos['w'], 'm':[pos['m'][0], pos['m'][1]]} 
    if pos['e'] == None:
        outPos['e'] = None
    else:
        outPos['e'] = [pos['e'][0],7-pos['e'][1]]
    return(outPos)


def sfSum(pos, func, *args):
    outSum = 0
    for x in range(8):
        for y in range(8):
            outSum += func(pos, (x, y), *args)
    return(outSum)
##### Main Eval #####
def mainEvaluation(pos):
    mg = middleGameEvaluation(pos)
    eg = endGameEvaluation(pos)
    p = phase(pos)
    t = tempo(pos)
    eg = eg * scaleFactor(pos, eg) / 64
    return( (((mg * p + (int(eg * (128 - p)) << 0)) // 128) << 0) + t )

def middleGameEvaluation(pos, noInitiative=True):
    v = 0
    v += pieceValueMg(pos) - pieceValueMg(colorflip(pos))
    v += psqtMg(pos) - psqtMg(colorflip(pos))
    v += imbalanceTotal(pos)
    v += pawnsMg(pos) - pawnsMg(colorflip(pos))
    v += piecesMg(pos) - piecesMg(colorflip(pos))
    v += mobilityMg(pos) - mobilityMg(colorflip(pos))
    v += threatsMg(pos) - threatsMg(colorflip(pos))
    v += passedMg(pos) - passedMg(colorflip(pos))
    v += space(pos) - space(colorflip(pos))
    v += kingMg(pos) - kingMg(colorflip(pos))
    if not noInitiative:
        v += initiativeTotalMg(pos, v)
    return(v)

def endGameEvaluation(pos, noInitiative=True):
    v = 0
    v += pieceValueEg(pos) - pieceValueEg(colorflip(pos))
    v += psqtEg(pos) - psqtEg(colorflip(pos))
    v += imbalanceTotal(pos)
    v += pawnsEg(pos) - pawnsEg(colorflip(pos))
    v += piecesEg(pos) - piecesEg(colorflip(pos))
    v += mobilityEg(pos) - mobilityEg(colorflip(pos))
    v += threatsEg(pos) - threatsEg(colorflip(pos))
    v += passedEg(pos) - passedEg(colorflip(pos))
    v += kingEg(pos) - kingEg(colorflip(pos))
    if not noInitiative:
        v += initiativeTotalEg(pos, v)
    return(v)    

def scaleFactor(pos, eg=None):
    if eg == None:
        eg = endGameEvaluation(pos)
    if eg > 0:
        posW = pos
        posB = colorflip(pos)
    else:
        posW = colorflip(pos)
        posB = pos
    sf = 64
    pcW = pawnCount(posW)
    pcB = pawnCount(posB)
    npmW = nonPawnMaterial(posW)
    npmB = nonPawnMaterial(posB)
    bishopValueMg = 825
    bishopValueEg = 915
    rookValueMg = 1276
    if pcW == 0 and npmW - npmB <= bishopValueMg:
        if npmW < rookValueMg:
            sf = 0
        elif npmB <= bishopValueMg:
            sf = 4
        else:
            sf = 14
    if sf == 64:
        ob = oppositeBishops(pos)
        if ob and npmW == bishopValueMg and npmB == bishopValueMg:
            sf = 22
        else:
            if ob:
                sf = min(sf, 36 + 2 * pcW)
            else:
                sf = min(sf, 36 * 7 * pcW)
        rule50 = pos['m'][0]
        sf = max(0, sf - (((rule50 - 12) // 4) << 0))
    return(sf)

def phase(pos):
    midGameLimit = 15258
    endGameLimit = 3915
    npm = nonPawnMaterial(pos) + nonPawnMaterial(colorflip(pos))
    npm = max(endGameLimit, min(npm, midGameLimit))
    return((((npm - endGameLimit) * 128) // (midGameLimit - endGameLimit)) << 0)

def tempo(pos, square=None):
    if square != None:
        return(0)
    if pos['w']:
        return(28)
    else:
        return(-28)
##### Pawns #####
def pawnsMg(pos, square=None):
    if square == None:
        return(sfSum(pos, pawnsMg))
    v = 0
    if isolated(pos, square):
        v -= 5
    elif backward(pos, square):
        v -= 9
    if doubled(pos, square):
        v -= 11
    if connected(pos, square):
        v += connectedBonus(pos, square)
    v -= 13 * weakUnopposedPawn(pos, square)
    return(v)

def pawnsEg(pos, square=None):
    if square == None:
        return(sfSum(pos, pawnsEg))
    v = 0
    if isolated(pos, square):
        v -= 15
    elif backward(pos, square):
        v -= 24
    if doubled(pos, square):
        v -= 56
    # HACKY FIX WARNING!
    # Verify with someone who actually knows javascript
    if connected(pos, square):
        v += (connectedBonus(pos,square) * (rank(pos, square) - 3) // 4 << 0) + 1
    v -= 27 * weakUnopposedPawn(pos, square)
    v -= 56 * weakLever(pos, square)
    return(v)

def isolated(pos, square=None):
    if square == None:
        return(sfSum(pos, isolated))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    for y in range(8):
        if sfBoard(pos, square[0]-1, y) == "P":
            return(0)
        if sfBoard(pos, square[0]+1, y) == "P":
            return(0)
    return(1)

def backward(pos, square=None):
    if square == None:
        return(sfSum(pos, backward))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    for y in range(square[1], 8):
        if sfBoard(pos, square[0]-1, y) == "P" or sfBoard(pos, square[0]+1, y) == "P":
            return(0)
    if (sfBoard(pos, square[0]-1, square[1]-2) == "p" or
       sfBoard(pos, square[0]+1, square[1]-2) == "p" or
       sfBoard(pos, square[0], square[1]-1) == "p"):
        return(1)
    return(0)

def doubled(pos, square=None):
    if square == None:
        return(sfSum(pos, doubled))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    if sfBoard(pos, square[0], square[1]+1) != "P":
        return(0)
    if sfBoard(pos, square[0]-1, square[1]+1) == "P":
        return(0)
    if sfBoard(pos, square[0]+1, square[1]+1) == "P":
        return(0)
    return(1)

def connected(pos, square=None):
    if square == None:
        return(sfSum(pos, connected))
    if supported(pos, square) or phalanx(pos, square):
        return(1)
    return(0)

def supported(pos, square=None):
    if square == None:
        return(sfSum(pos, supported))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    s = 0 
    if sfBoard(pos, square[0]-1, square[1]+1) == "P":
        s += 1
    if sfBoard(pos, square[0]+1, square[1]+1) == "P":
        s += 1
    return(s)

def phalanx(pos, square=None):
    if square == None:
        return(sfSum(pos, phalanx))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    if sfBoard(pos, square[0]-1, square[1]) == "P":
        return(1)
    if sfBoard(pos, square[0]+1, square[1]) == "P":
        return(1)
    return(0)

def connectedBonus(pos, square=None):
    if square == None:
        return(sfSum(pos, connectedBonus))
    if not connected(pos, square):
        return(0)
    seed = [0, 7, 8, 12, 29, 48, 86]
    op = opposed(pos, square)
    ph = phalanx(pos, square)
    su = supported(pos, square)
    r = rank(pos, square)
    if r < 2 or r > 7:
        return(0)
    return(seed[r-1] * (2+ph-op) + 21 * su)

def opposed(pos, square=None):
    if square == None:
        return(sfSum(pos, opposed))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    for y in range(square[1]):
        if sfBoard(pos, square[0], y) == "p":
            return(1)
    return(0)

def weakUnopposedPawn(pos, square=None):
    if square == None:
        return(sfSum(pos, weakUnopposedPawn))
    if opposed(pos, square):
        return(0)
    v = 0
    if isolated(pos, square):
        v += 1
    elif backward(pos, square):
        v += 1
    return(v)

def weakLever(pos, square=None):
    if square == None:
        return(sfSum(pos, weakLever))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    if sfBoard(pos, square[0] - 1, square[1] - 1) != "p":
        return(0)
    if sfBoard(pos, square[0] + 1, square[1] - 1) != "p":
        return(0)
    if sfBoard(pos, square[0] - 1, square[1] + 1) == "P":
        return(0)
    if sfBoard(pos, square[0] + 1, square[1] + 1) == "P":
        return(0)
    return(1)



##### Pieces #####
def piecesMg(pos, square=None):
    if square == None:
        return sfSum(pos, piecesMg)
    myPiece = sfBoard(pos, square[0], square[1])
    if "NBRQ".find(myPiece) < 0:
        return(0)
    v = 0;
    v += [0,32,30,60][outpostTotal(pos, square)]
    v += 18 * minorBehindPawn(pos, square)
    v -= 3 * bishopPawns(pos, square)
    v += 7 * rookOnQueenFile(pos, square)
    v += [0,21,47][rookOnFile(pos, square)]
    if pos['c'][0] or pos['c'][1]:
        v -= trappedRook(pos, square) * 52 * 1
    else:
        v -= trappedRook(pos, square) * 52 * 2
    v -= 49 * weakQueen(pos, square)
    v -= 7 * kingProtector(pos, square)
    v += 45 * longDiagonalBishop(pos, square)
    return(v)

def piecesEg(pos, square=None):
    if square == None:
        return(sfSum(pos, piecesEg))
    if "NBRQ".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    v = 0
    v += [0,10,21,42][outpostTotal(pos, square)]
    v += 3 * minorBehindPawn(pos, square)
    v -= 7 * bishopPawns(pos, square)
    v += 6 * rookOnQueenFile(pos, square)
    v += [0,4,25][rookOnFile(pos, square)]
    if (pos['c'][0] or pos['c'][1]):
        v -= trappedRook(pos, square) * 10 * 1
    else:
        v -= trappedRook(pos, square) * 10 * 2
    v -= 15 * weakQueen(pos, square)
    v -= 8 * kingProtector(pos, square)
    return(v)

def outpostTotal(pos, square=None):
    if square == None:
        return(sfSum(pos, outpostTotal))
    myPiece = sfBoard(pos, square[0], square[1])

    if myPiece != "N" and myPiece != "B":
        return(0)
       
    knight = myPiece == "N"
    reachable = 0
    if not (outpost(pos, square)):
        if not knight:
            return(0)
        reachable = reachableOutpost(pos, square)
        if not reachable:
            return(0)
        else:
            return(1)
    if knight:
        return(3)
    else:
        return(2)

def outpost(pos, square=None):
    if square == None:
        return(sfSum(pos, outpost))
    myPiece = sfBoard(pos, square[0], square[1])
    if myPiece != "B" and myPiece != "B":
        return(0)
    if not outpostSquare(pos, square):
        return(0)
    else:
        return(1)

def outpostSquare(pos, square=None):
    if square == None:
        return(sfSum(pos, outpostSquare))
    if rank(pos, square) < 4 or rank(pos, square) > 6:
        return(0)
    if (sfBoard(pos, square[0]-1, square[1]+1) != "P" and
       sfBoard(pos, square[0]+1, square[1]+1) != "P"):
        return(0)
    pos2 = colorflip(pos)
    for y in range(square[1]):
        if (sfBoard(pos, square[0]+1, y) == "p" and
           (y == square[1]-1 or
           (sfBoard(pos, square[0]-1, y+1) != "P" and
           not backward(pos2, square[0]-1, 7-y)))):
            return(0)
        if (sfBoard(pos, square[0]+1, y+1) != "p" and
           (y == square[1]-1 or
           (sfBoard(pos, square[0]+1, y+1) != "P" and
           not backward(pos2, square[0]+1, 7-y)))):
            return(0)
    return(1)

def reachableOutpost(pos, square=None):
    if square == None:
        return(sfSum(pos, reachableOutpost))
    myPiece = sfBoard(pos, square[0], square[1])
    if myPiece != "B" and myPiece != "N":
        return(0)
    v = 0
    for x in range(8):
        for y in range(8):
            if ((myPiece == "N" and
              "PNBRQK".find(sfBoard(pos, x, y)) < 0 and
              knightAttack(pos, (x,y), square) and
              outpostSquare(pos, (x,y))) or
              (myPiece == "B" and
              "PNBRQK".find(sfBoard(pos, x, y)) < 0 and
              bishopXrayAttack(pos, (x,y), square) and
              outpostSquare(pos, (x-1, y-1)))):
                support = (sfBoard(pos, x-1, y+1) == "P" or sfBoard(pos, x+1, y+1) == "P") + 1
                v = max(v, support)
    return(v)
        
def minorBehindPawn(pos, square=None):
    if square == None:
        return(sfSum(pos, minorBehindPawn))
    if (sfBoard(pos, square[0], square[1]) != "B" and
       sfBoard(pos, square[0], square[1]) != "N"):
        return(0)
    if sfBoard(pos, square[0], square[1] -1).upper() != "P":
        return(0)
    return(1)


def bishopPawns(pos, square=None):
    if square == None:
        return(sfSum(pos, bishopPawns))
    if sfBoard(pos, square[0], square[1]) != "B":
        return(0)
    c = (square[0] + square[1]) % 2
    v = 0
    blocked = 0
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "P" and c == (x + y) % 2:
                v += 1
            if (sfBoard(pos, x, y) == "P" and
               x > 1 and x < 6 and
               sfBoard(pos, x, y - 1) != "-"):
                blocked += 1
    return(v * (blocked + 1))


def rookOnQueenFile(pos, square=None):
    if square == None:
        return(sfSum(pos, rookOnQueenFile))
    if sfBoard(pos, square[0], square[1]) != "R":
        return(0)
    for y in range(8):
        if sfBoard(pos, square[0], y).upper() == "Q":
            return(1)
    return(0)

def rookOnFile(pos, square=None):
    if square == None:
        return(sfSum(pos, rookOnFile))
    if sfBoard(pos, square[0], square[1]) != "R":
        return(0)
    sfOpen = 1
    for y in range(8):
        if sfBoard(pos, square[0], y) == "P":
            return(0)
        if sfBoard(pos, square[0], y) == "p":
            return(0)
    return(sfOpen + 1)

def trappedRook(pos, square=None):
    if square == None:
        return(sfSum(pos, trappedRook))
    if sfBoard(pos, square[0], square[1]) != "R":
        return(0)
    if rookOnFile(pos, square):
        return(0)
    if mobility(pos, square) > 3:
        return(0)
    kx = 0
    ky = 0
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "K":
                kx = x
                ky = y
    if (kx < 4) != (square[0] < kx):
        return(0)
    return(1)

def weakQueen(pos, square=None):
    if square == None:
        return(sfSum(pos, weakQueen))
    if sfBoard(pos, square[0], square[1]) != "Q":
        return(0)
    for i in range(8):
        ix = (i + (i > 3)) % 3 - 1
        iy = (((i + (i > 3)) // 3) << 0) - 1
        count = 0
        for d in range(1, 8):
            b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
            if b == "r" and (ix == 0 or iy == 0) and count == 1:
                return(1)
            if b == "b" and (ix == 0 or iy == 0) and count == 1:
                return(1)
            if b != "-":
                count += 1
    return(0)

def kingProtector(pos, square=None):
    if square == None:
        return(sfSum(pos, kingProtector))
    myPiece = sfBoard(pos, square[0], square[1])
    if myPiece != "N" and myPiece != "B":
        return(0)
    return(kingDistance(pos, square))


def longDiagonalBishop(pos, square=None):
    if square == None:
        return(sfSum(pos, longDiagonalBishop))
    if sfBoard(pos, square[0], square[1]) != "B":
        return(0)
    if (square[0] - square[1]) != 0 and square[0] - (7 - square[1]) != 0:
        return(0)
    x1 = square[0]
    y1 = square[1]
    if min(x1, 7-x1) > 2:
        return(0)
    for i in range(min(x1, 7-x1), 4):
        if sfBoard(pos, x1, y1) == "p":
            return(0)
        if sfBoard(pos, x1, y1) == "P":
            return(0)
        if x1 < 4:
            x1 += 1
        else:
            x1 -= 1
        if y1 < 4:
            y1 += 1
        else:
            y1 -= 1
    return(1)

###ATTACK###
def pinnedDirection(pos, square=None):
    if square == None:
        return(sfSum(pos, pinnedDirection))
    myPiece = sfBoard(pos, square[0], square[1])
    if "PNBRQK".find(myPiece.upper()) < 0:
        return(0)
    color = 1 
    if "PNBRQK".find(myPiece) < 0:
        color = -1
    for i in range(8):
        ix = (i + (i > 3)) % 3 - 1
        iy = (((i + (i > 3)) // 3) << 0) - 1
        king = False
        for d in range(1, 8):
            b = sfBoard(pos, square[0] - d * ix, square[1] - d * iy)
            if b == "K":
                king = True
            if b != '-':
                break
    if king:
        for d in range(1,8):
            b = sfBoard(pos, square[0] - d * ix, square[1] - d * iy)
            if (b == "q" or 
             b == "b" and ix * iy != 0 or
             b == "r" and ix * iy == 0):
                return(abs(ix + iy * 3) * color)
            if b != "-":
                break
    return(0)

def pinned(pos, square=None):
    if square == None:
        return(sfSum(pos, pinned))
    myPiece = sfBoard(pos,  square[0], square[1])
    if "PNBRQK".find(myPiece) < 0:
        return(0)
    if pinnedDirection(pos, square) > 0:
        return(1)
    return(0)

def knightAttack(pos, square=None, s2=None):
    if square == None:
        return(sfSum(pos, knightAttack))
    v = 0
    for i in range(8):
        ix = ((i > 3) + 1) * (((i % 4) > 1) * 2 - 1)
        iy = (2 - (i > 3)) * ((i % 2 == 0) * 2 - 1)
        b = sfBoard(pos, square[0] + ix, square[1] + iy)

        if (b == "N" and
         (s2 == None or s2[0] == square[0] + ix and
         s2[1] == square[1] + iy) and
         not pinned(pos, (square[0]+ix, square[1]+iy))):
            v += 1
    return(v)

def bishopXrayAttack(pos, square=None, s2=None):
    if square == None:
        return(sfSum(pos, bishopXrayAttack))
    v = 0
    for i in range(4):
        ix = ((i > 1) * 2 - 1)
        iy = ((i % 2 == 0) * 2 - 1)
        for d in range(1,8):
            b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
            if (b == "B" and
             (s2 == None or s2[0] == square[0] + d * ix and s2[1] == square[1] + d * iy)):
                direc = pinnedDirection(pos, (square[0]+d*ix, square[1]+d*iy))
                if direc == 0 or abs(ix+iy*3) == direc:
                    v += 1
            if b != "-" and b != "Q" and b != "q":
                break
    return(v)

def rookXrayAttack(pos, square=None, s2=None):
    if square == None:
        return(sfSum(pos, rookXrayAttack))
    v = 0
    for i in range(4):
        if i == 0:
            ix = -1
        elif i == 1:
            ix = 1
        else:
             ix = 0
        if i == 2:
            iy = -1
        elif i == 3:
            iy = 1
        else:
            iy = 0
        for d in range(1,8):
            b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
            if (b == "R" and
             (s2 == None or s2[0] == square[0] + d * ix and s2[1] == square[1] + d * iy)):
                direc = pinnedDirection(pos, (square[0]+d*ix, square[1]+d*iy))
                if direc == 0 or abs(ix+iy*3) == direc:
                    v += 1
            if b != "-" and b != "R" and b != "Q" and b != "q":
                break
    return(v)

def queenAttack(pos, square=None, s2=None):
    if square == None:
        return(sfSum(pos, queenAttack))
    v = 0
    for i in range(8):
        ix = (i + (i > 3)) % 3 - 1
        iy = (((i + (i > 3)) // 3) << 0) - 1
        for d in range(1,8):
            b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
            if (b == "Q" and
               (s2 == None or s2[0] == square[0]  + d * ix and s2[1] == square[1] + d * iy)):
                direc = pinnedDirection(pos, (square[1]+d*ix, square[1]+d*iy))
                if direc == 0 or abs(ix+iy*3) == direc:
                    v += 1
            if b != "-":
                break
    return(v)

def pawnAttack(pos, square=None):
    if square == None:
        return(sfSum(pos, pawnAttack))
    v = 0
    if sfBoard(pos, square[0] - 1, square[1] + 1) == "P":
        v += 1
    if sfBoard(pos, square[0] + 1, square[1] + 1) == "P":
        v += 1
    return(v)

def kingAttack(pos, square=None):
    if square == None:
        return(sfSum(pos, kingAttack))
    for i in range(8):
        ix = (i + (i > 3)) % 3 - 1
        iy = (((i + (i > 3)) // 3) << 0) - 1
        if sfBoard(pos, square[0] + ix, square[1] + iy) == "K":
            return(1)
    return(0)

def attack(pos, square=None):
    if square == None:
        return(sfSum(pos, attack))
    v = 0
    v += pawnAttack(pos, square)
    v += kingAttack(pos, square)
    v += knightAttack(pos, square)
    v += bishopXrayAttack(pos, square)
    v += rookXrayAttack(pos, square)
    v += queenAttack(pos, square)
    return(v)

def queenAttackDiagonal(pos, square=None, s2=None):
    if square == None:
        return(sfSum(pos, queenAttackDiagonal))
    v = 0 
    for i in range(8):
        ix = (i + (i > 3)) % 3 - 1
        iy = iy = (((i + (i > 3)) // 3) << 0) - 1
        if ix == 0 or iy == 0:
            continue
        for d in range(1, 8):
            b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
            if (b == "Q" and
               (s2 == None or s2[0] == square[0] + d * ix and s2[1] == square[1] + d * iy)):
                direc = pinnedDirection(pos, (square[0]+d*ix, square[1]+d*iy))
                if direc == 0 or abs(ix+iy*3) == direc:
                    v += 1
            if b != "-":
                break
    return(v)

##### Helpers #####
def rank(pos, square=None):
    if square == None:
        return(sfSum(pos, rank))
    return(8-square[1])

def sfFile(pos, square):
    if square == None:
        return(sfSum(pos, sfFile))
    return(1 + square[0])

def bishopCount(pos, square=None):
    if square == None:
        return(sfSum(pos, bishopCount))
    elif sfBoard(pos, square[0], square[1] == "B"):
        return(1)
    return(0)

def queenCount(pos, square=None):
    if square == None:
        return(sfSum(pos, queenCount))
    if sfBoard(pos, square[0], square[1]) == "Q":
        return(1)
    return(0)

def pawnCount(pos, square=None):
    if square == None:
        return(sfSum(pos, pawnCount))
    if sfBoard(pos, square[0], square[1]) == "P":
        return(1)
    return(0)

def knightCount(pos, square=None):
    if square == None:
        return(sfSum(pos, knightCount))
    if sfBoard(pos, square[0], square[1]) == "N":
        return(1)
    return(0)


def rookCount(pos, square=None):
    if square == None:
        return(sfSum(pos, rookCount))
    if sfBoard(pos, square[0], square[1]) == "R":
        return(1)
    return(0)

def oppositeBishops(pos):
    if bishopCount(pos) != 1:
        return(0)
    if bishopCount(colorflip(pos)) != 1:
        return(0)
    color = [0,0]
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "B":
                color[0] = (x + y) % 2
            if sfBoard(pos, x, y) == "b":
                color[1] = (x + y) % 2
    if color[0] == color[1]:
        return(0)
    else:
        return(1)

def kingDistance(pos, square=None):
    if square == None:
        return(sfSum(pos, kingDistance))
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "K":
                return(max(abs(x - square[0]), abs(y-square[1])))
    return(0)

def kingRing(pos, square=None, full=False):
    if square == None:
        return(sfSum(pos, kingRing))
    if (not full and
       sfBoard(pos, square[0] + 1, square[1] - 1) == "p" and
       sfBoard(pos, square[0] - 1, square[1] - 1) == "p"):
        return(0)
    for ix in range(-2, 3):
        for iy in range(-2,3):
            if (sfBoard(pos, square[0] + ix, square[1] + iy) == "k" and
               (ix >= -1 and ix <= 1 or square[0] + ix == 0 or square[0] + ix == 7) and
               (iy >= -1 and iy <= 1 or square[1] + iy == 0 or square[1] + iy == 7)):
                return(1)
    return(0)

##### Imbalance #####
def imbalanceTotal(pos, square=None):
    v = 0
    v += imbalance(pos) - imbalance(colorflip(pos))
    v += bishopPair(pos) - bishopPair(colorflip(pos))
    return((v//16) >> 0)

def imbalance(pos, square=None):
    if square == None:
        return(sfSum(pos, imbalance))
    qo = [[0],[40,38],[32,255,-62],[0,104,4,0],[-26,-2,47,105,-208],[-189,24,117,133,-134,-6]]
    qt = [[0],[36,0],[9,63,0],[59,65,42,0],[46,39,24,-24,0],[97,100,-42,137,268,0]]

    myPiece = sfBoard(pos, square[0], square[1])
    j = "XPNBRQxpnbrq".find(myPiece)
 
    if (j < 0 or j > 5):
        return 0;
    bishop = [0, 0]
    v = 0
    for x in range(8):
        for y in range(8):
            tmpPiece = sfBoard(pos, x, y) 
            i = "XPNBRQxpnbrq".find(tmpPiece)

            if i < 0:
                continue
            if i == 9:
                bishop[0] += 1
            if i == 3:
                bishop[1] += 1
            if i % 6 > j:
                continue
            if i > 5:
                v += qt[j][i-6]
            else:
                v += qo[j][i]
    if bishop[0] > 1:
        v += qt[j][0]
    if bishop[1] > 1:
        v += qo[j][0]
    return(v)

def bishopPair(pos, square=None): 
    if bishopCount(pos) < 2:
        return(0)
    elif square == None:
        return(1438)
    elif sfBoard(pos, square[0], square[1]) == "B":
        return(1)
    else:
        return(0)

##### Initiative #####
def initiative(pos, square=None):
    if square != None:
        return(0)
    pawns = 0 
    kx = [0, 0]
    ky = [0, 0]           
    flanks = [0, 0]
    for x in range(8):
        sfOpen = [0, 0]
        for y in range(8):
            if sfBoard(pos, x, y).upper() == "P":
                sfOpen[not (sfBoard(pos, x, y) == "P")] = 1
                pawns += 1
            if sfBoard(pos, x, y).upper() == "K":
                kx[not (sfBoard(pos, x, y) == "K")] = x
                ky[not (sfBoard(pos, x, y) == "K")]  = y
        if (sfOpen[0]  + sfOpen[1]) > 0:
            flanks[not (x < 4)] = 1
    
    pos2 = colorflip(pos)
    passedCount = candidatePassed(pos) + candidatePassed(pos2)
    bothFlanks = flanks[0] and flanks[1]
    outflanking = abs(kx[0] - kx[1]) - abs(ky[0] - ky[1])
    purePawn = nonPawnMaterial(pos) + nonPawnMaterial(pos2) == 0
    almostUnwinnable = passedCount == 0 and outflanking < 0 and bothFlanks == 0
    v = 9 * passedCount + 11 * pawns + 9 * outflanking + 21 * bothFlanks + 51 * purePawn - 43 * almostUnwinnable - 95
    return(v)

def initiativeTotalMg(pos, v=None):
    if v == None:
        v = middleGameEvaluation(pos, True)
    if v > 0:
        return(1 * max( min(initiative(pos)+50, 0), -(abs(v))))
    elif v < 0:
        return(-1 * max( min(initiative(pos)+50, 0), -(abs(v))))
    else:
        return(0 * max( min(initiative(pos)+50, 0), -(abs(v))))

def initiativeTotalEg(pos, v=None):
    if v == None:
        v = endGameEvaluation(pos, True)
    if v > 0:
        return(1 * max( initiative(pos), -abs(v)))
    elif v < 0:
        return(-1 * max( initiative(pos), -abs(v)))
    else:
        return(0 * max( initiative(pos), -abs(v)))



##### King #####
def pawnlessFlank(pos):
    pawns = [0,0,0,0,0,0,0,0]
    kx = 0
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y).upper() == "P":
                pawns[x] += 1
            if sfBoard(pos, x, y) == "k":
                kx = x
    mySum = 0
    if kx == 0:
        mySum = pawns[0] + pawns[1] + pawns[2]
    elif kx < 3:
        mySum =  pawns[0] + pawns[1] + pawns[2] + pawns[3]
    elif kx < 5:
        mySum = pawns[2] + pawns[3] + pawns[4] + pawns[5]
    elif kx < 7:
        mySum = pawns[4] + pawns[5] + pawns[6] + pawns[7]
    else:
        mySum = pawns[5] + pawns[6] + pawns[7]
    return(mySum == 0)

def strengthSquare(pos, square=None):
    if square == None:
        return(sfSum(pos, strengthSquare))
    v = 5
    kx = min(6, max(1, square[0]))
    weakness = [[-6,81,93,58,39,18,25],
      [-43,61,35,-49,-29,-11,-63],
      [-10,75,23,-2,32,3,-45],
      [-39,-13,-29,-52,-48,-67,-166]]
    for x in range(kx-1, kx+2):
        us = 0
        for y in range(7, square[1]-1, -1):
            if sfBoard(pos, x, y) == "p":
                us = y
        f = min(x, 7-x)
        v += weakness[f][us] or 0
    return(v)

def stormSquare(pos, square=None, eg=False):
    if square == None:
        return(sfSum(pos, stormSquare))
    v = 0
    ev = 5
    kx = min(6, max(1, square[0]))
    unblockedstorm = [
        [85,-289,-166,97,50,45,50],
        [46,-25,122,45,37,-10,20],
        [-6,51,168,34,-2,-22,-14],
        [-15,-11,101,4,11,-15,-29]]
    for x in range(kx-1,kx+2):
        us = 0
        them = 0
        for y in range(7, square[1]-1, -1):
            if sfBoard(pos, x, y) == "p":
                us = y
            if sfBoard(pos, x, y) == "P":
                them = y
        f = min(x, 7-x)
        if us > 0 and them == us + 1:
            v += 82 * (them == 2)
            ev += 82 * (them == 2)
        else:
            v += unblockedstorm[f][them]
    if eg:
        return(ev)
    else:
        return(v)

def shelterStrength(pos, square=None):
    w = 0
    s = 1024
    tx = None
    for x in range(8):
        for y in range(8):
            if (sfBoard(pos, x, y) == "k" or
              pos['c'][2] and x == 6 and y == 0 or
              pos['c'][3] and x == 2 and y == 0):
                w1 = strengthSquare(pos, (x, y))
                s1 = stormSquare(pos, (x,y))
                if s1 - w1 < s - w:
                    w = w1
                    s = s1
                    tx = max(1, min(6,x))
    if square == None:
        return(w)
    if (tx != None and sfBoard(pos, square[0], square[1]) == "p" and 
      square[0] >= tx-1 and square[0] <= tx+1):
        for y in range(square[1]-1, -1, -1):
            if sfBoard(pos, square[0], y) == "p":
                return(0)
        return(1)
    return(0)

def shelterStorm(pos, square=None):
    w = 0 
    s = 1024
    tx = None
    for x in range(8):
        for y in range(8):
            if (sfBoard(pos, x, y) == "k" or
              pos['c'][2] and x == 6 and y == 0 or
              pos['c'][3] and x == 2 and y == 0):
                w1 = strengthSquare(pos, (x, y))
                s1 = stormSquare(pos, (x,y))
                if s1 - w1 < s - w:
                    w = w1
                    s = s1
                    tx = max(1, min(6,x))
    if square == None:
        return(s)
    if (tx != None and sfBoard(pos, square[0], square[1]).upper() == "P" and 
      square[0] >= tx-1 and square[0] <= tx+1):
        for y in range(square[1]-1, -1, -1):
            if sfBoard(pos, square[0], y) == sfBoard(pos, square[0], square[1]):
                return(1)
    return(0)
        
def kingPawnDistance(pos, square=None):
    v = 8
    kx = 0
    ky = 0
    px = 0
    py = 0
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "K":
                kx = x
                ky = y
    for x in range(8):
        for y in range(8):
            dist = max(abs(x-kx), abs(y-ky))
            if sfBoard(pos, x, y) == "P" and dist < v:
                px = x
                py = y
                v = dist
    if v < 8 and (square == None or square[0] == px and square[1] == py):
        return(v)
    return(0)

def check(pos, square=None, myType=None):
    if square == None:
        return(sfSum(pos, check))
    if (rookXrayAttack(pos, square) and
      (myType == None or myType == 2 or myType == 4) or
      queenAttack(pos, square) and
      (myType == None or myType == 3)):
        for i in range(4):
            if i == 0:
                ix = -1
            elif i == 1:
                ix = 1
            else:
                ix = 0
            if i == 2:
                iy = -1
            elif i == 3:
                iy = 1
            else:
                iy = 0
            for d in range(1,8):
                b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
                if b == 'k':
                    return(1)
                if b != "-" and b != "q":
                    break
    if (bishopXrayAttack(pos, square) and
      (myType == None or myType == 1 or myType == 4) or
      queenAttack(pos, square) and
      (myType == None or myType == 3)):
        for i in range(4):
            ix = (i > 1) * 2 - 1
            iy = (i % 2 == 0) * 2 -1
            for d in range(1,8):
                b = sfBoard(pos, square[0] + d * ix, square[1] + d * iy)
                if b == "k":
                    return(1)
                if b != "-" and b != "q":
                    break
    if (knightAttack(pos, square) and 
      (myType == None or myType == 0 or myType == 4)):
        if (sfBoard(pos, square[0] + 2, square[1] + 1) == "k" or
          sfBoard(pos, square[0] + 2, square[1] - 1) == "k" or
          sfBoard(pos, square[0] + 1, square[1] + 2) == "k" or
          sfBoard(pos, square[0] + 1, square[1] - 2) == "k" or
          sfBoard(pos, square[0] - 2, square[1] + 1) == "k" or
          sfBoard(pos, square[0] - 2, square[1] - 1) == "k" or
          sfBoard(pos, square[0] - 1, square[1] + 2) == "k" or
          sfBoard(pos, square[0] - 1, square[1] - 2) == "k"):
            return(1)
    return(0) 

def weakSquares(pos, square=None):
    if square == None:
        return(sfSum(pos, weakSquares))
    if attack(pos, square):
        pos2 = colorflip(pos)
        myAttack = attack(pos2, (square[0], 7-square[1]))
        if myAttack >= 2:
            return(0)
        if myAttack == 0:
            return(1)
        if (kingAttack(pos2, (square[0], 7-square[1])) or
          queenAttack(pos2, (square[0], 7-square[1]))):
            return(1)
    return(0)

def safeCheck(pos, square=None, myType=None):
    if square == None:
        return(sfSum(pos, safeCheck, myType))
    if "PNBRQK".find(sfBoard(pos, square[0], square[1])) >= 0:
        return(0)
    if not check(pos, square, myType):
        return(0)
    pos2 = colorflip(pos)
    if myType == 3 and safeCheck(pos, square, 2):
        return(0)
    if myType == 1 and safeCheck(pos, square, 3):
        return(0)
    if ((not attack(pos2, (square[0], 7-square[1])) or
      (weakSquares(pos, square) and attack(pos, square) > 1)) and
      (myType != 3 or not queenAttack(pos2, (square[0], 7-square[1])))):
        return(1)
    return(0)

def kingAttackersCount(pos, square=None):
    if square == None:
        return(sfSum(pos, kingAttackersCount))
    if "PNBRQ".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    if sfBoard(pos, square[0], square[1]) == "P":
        v = 0
        for direc in range(-1, 2, 2):
            fr = sfBoard(pos, square[0] + direc * 2, square[1]) == "P"
            if (square[0] + direc >= 0 and square[0] + direc < 7 and
              kingRing(pos, (square[0]+direc, square[1]-1), True)):
                if fr:
                    v = v + 0.5
                else:
                    v = v + 1
        return(v)
    for x in range(8):
        for y in range(8):
            s2 = (x,y)
            if kingRing(pos, s2):
                if (knightAttack(pos, s2, square) or
                  bishopXrayAttack(pos, s2, square) or
                  rookXrayAttack(pos, s2, square) or
                  queenAttack(pos, s2, square)):
                    return(1)
    return(0)

def kingAttackersWeight(pos, square=None):
    if square == None:
        return(sfSum(pos, kingAttackersWeight))
    myPiece = sfBoard(pos, square[0], square[1])
    if kingAttackersCount(pos, square):
        return([0,81,52,44,10]["PNBRQ".find(myPiece)])
    return(0)

def kingAttacks(pos, square=None):
    if square == None:
        return(sfSum(pos, kingAttacks))
    if "NBRQ".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    if kingAttackersCount(pos, square) == 0:
        return(0)
    kx = 0
    ky = 0
    v = 0 
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "k":
                kx = x
                ky = y
    for x in range(kx-1, kx+2):
        for y in range(ky-1,ky+2):
            s2 = (x,y)
            if x >= 0 and y >= 0 and x <= 7 and y <= 7 and (x != kx or y != ky):
                v += knightAttack(pos, s2, square)
                v += bishopXrayAttack(pos, s2, square)
                v += rookXrayAttack(pos, s2, square)
                v += queenAttack(pos, s2, square)
    return(v)

def weakBonus(pos, square=None):
    if square == None:
        return(sfSum(pos, weakBonus))
    if not weakSquares(pos, square):
        return(0)
    if not kingRing(pos, square):
        return(0)
    return(1)

def unsafeChecks(pos, square=None):
    if square == None:
        return(sfSum(pos, unsafeChecks))
    if check(pos, square, 0) and safeCheck(pos, None, 0) == 0:
        return(1)
    if check(pos, square, 1) and safeCheck(pos, None, 1) == 0:
        return(1)
    if check(pos, square, 2) and safeCheck(pos, None, 2) == 0:
        return(1)
    return(0)

def knightDefender(pos, square=None):
    if square == None:
        return(sfSum(pos, knightDefender))
    if knightAttack(pos, square) and kingAttack(pos, square):
        return(1)
    return(0)

def endgameShelter(pos, square=None):
    w = 0
    s = 1024
    tx = None
    for x in range(8):
        for y in range(8):
            if (sfBoard(pos, x, y) == "k" or
              pos['c'][2] and x == 6 and y == 0 or
              pos['c'][3] and x == 2 and y == 0):
                w1 = strengthSquare(pos, (x,y))
                s1 = stormSquare(pos, (x,y))
                e1 = stormSquare(pos, (x,y), True)
                if s1 - w1 < s - w:
                    w = w1
                    s = s1
                    e = e1
    if square == None:
        return(e)
    return(0)
 
def blockersForKing(pos, square=None):
    if square == None:
        return(sfSum(pos, blockersForKing))
    if pinnedDirection(colorflip(pos), (square[0], 7-square[1])):
        return(1)
    return(0)

def flankAttack(pos, square=None):
    if square == None:
        return(sfSum(pos, flankAttack))
    if square[1] > 4:
        return(0)
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "k":
                if x == 0 and square[0] > 2:
                    return(0)
                if x < 3 and square[0] > 3:
                    return(0)
                if x >=3 and x < 5 and (square[0] < 2 or square[0] > 5):
                    return(0)
                if x >= 5 and square[0] < 4:
                    return(0)
                if x == 7 and square[0] < 5:
                    return(0)
    a = attack(pos, square)
    if not a:
        return(0)
    return((a > 1) + 1)

def flankDefense(pos, square=None):
    if square == None:
        return(sfSum(pos, flankDefense))
    if square[1] > 4:
        return(0)
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "k":
                if x == 0 and square[0] > 2:
                    return(0)
                if x < 3 and square[0] > 3:
                    return(0)
                if x >= 3 and x < 5 and (square[0] < 2 or square[0] > 5):
                    return(0)
                if x >= 5 and square[0] < 4:
                    return(0)
                if x == 7 and square[0] < 5:
                    return(0)
    a = attack(colorflip(pos), (square[0], 7-square[1])) > 0
    return(a)

def kingDanger(pos):
    count = kingAttackersCount(pos)
    weight = kingAttackersWeight(pos)
    myKingAttacks = kingAttacks(pos)
    weak = weakBonus(pos)
    myUnsafeChecks = unsafeChecks(pos)
    myBlockersForKing = blockersForKing(pos)
    kingFlankAttack = flankAttack(pos)
    kingFlankDefense = flankDefense(pos)
    noQueen = not queenCount(pos)
    v = count * weight \
      + 69 * myKingAttacks \
      + 185 * weak \
      - 100 * (knightDefender(colorflip(pos)) > 0) \
      + 148 * myUnsafeChecks \
      + 98 * myBlockersForKing \
      - 4 * kingFlankDefense \
      + ((3 * kingFlankAttack * kingFlankAttack // 8) << 0) \
      - 873 * noQueen \
      - ((6 * (shelterStrength(pos) - shelterStorm(pos)) // 8) << 0) \
      + mobilityMg(pos) - mobilityMg(colorflip(pos)) \
      + 37 \
      + 780 * (safeCheck(pos, None, 3) > 0) \
      + 1080 * (safeCheck(pos, None, 2) > 0) \
      + 635 * (safeCheck(pos, None, 1) > 0) \
      + 790 * (safeCheck(pos, None, 0) > 0)
    if v > 100:
        return(v)
    return(0)

def kingMg(pos):
    v = 0
    kd = kingDanger(pos)
    v -= shelterStrength(pos)
    v += shelterStorm(pos)
    v += (kd * kd // 4096) << 0
    v += 8 * flankAttack(pos)
    v += 17 * pawnlessFlank(pos)
    return(v)

def kingEg(pos):
    v = 0
    v -= 16 * kingPawnDistance(pos)
    v += endgameShelter(pos)
    v += 95 * pawnlessFlank(pos)
    v += (kingDanger(pos) // 16) << 0
    return(v)

##### Material #####
def nonPawnMaterial(pos, square=None):
    if square == None:
        return(sfSum(pos, nonPawnMaterial))
    myPiece = sfBoard(pos, square[0], square[1])
    i = "NBRQ".find(myPiece)
    if i >= 0:
        return(pieceValueBonus(pos, square, True))
    return(0)


def pieceValueMg(pos, square=None):
    # if no square is specified, calculates values of pieces for
    # all squares on board.
    if square == None:
        return(sfSum(pos, pieceValueMg))
    # if square is specified (a length two tuple of (x,y)), 
    # get the pieceValueBonus of specified square.
    else:
        return(pieceValueBonus(pos, square, True))

def pieceValueEg(pos, square=None):
    if square == None:
        return(sfSum(pos, pieceValueEg))
    return(pieceValueBonus(pos, square, False))

def pieceValueBonus(pos, square=None, mg=True):
    if square == None:
        return(sfSum(pos, pieceValueBonus))
    if mg:
        a = [128, 781, 825, 1276, 2538]
    else:
        a = [213, 854, 915, 1380, 2682]
    myPiece = sfBoard(pos, square[0], square[1])
    i = "PNBRQ".find(myPiece)
    if (i >= 0):
        return(a[i])
    else:
        return(0)

def psqtMg(pos, square=None):
    if square == None:
        return(sfSum(pos, psqtMg))
    return(psqtBonus(pos, square, True))

def psqtEg(pos, square=None):
    if square == None:
        return(sfSum(pos, psqtEg))
    return(psqtBonus(pos, square, False)) 

def psqtBonus(pos, square=None, mg=True):
    if square == None:
        return(sfSum(pos, psqtBonus, mg))
    if mg:
        bonus = [[[-175,-92,-74,-73],[-77,-41,-27,-15],[-61,-17,6,12],[-35,8,40,49],[-34,13,44,51],[-9,22,58,53],[-67,-27,4,37],[-201,-83,-56,-26]],
            [[-53,-5,-8,-23],[-15,8,19,4],[-7,21,-5,17],[-5,11,25,39],[-12,29,22,31],[-16,6,1,11],[-17,-14,5,0],[-48,1,-14,-23]],
            [[-31,-20,-14,-5],[-21,-13,-8,6],[-25,-11,-1,3],[-13,-5,-4,-6],[-27,-15,-4,3],[-22,-2,6,12],[-2,12,16,18],[-17,-19,-1,9]],
            [[3,-5,-5,4],[-3,5,8,12],[-3,6,13,7],[4,5,9,8],[0,14,12,5],[-4,10,6,8],[-5,6,10,8],[-2,-2,1,-2]],
            [[271,327,271,198],[278,303,234,179],[195,258,169,120],[164,190,138,98],[154,179,105,70],[123,145,81,31],[88,120,65,33],[59,89,45,-1]]] 
        pbonus = [[0,0,0,0,0,0,0,0],[3,3,10,19,16,19,7,-5],[-9,-15,11,15,32,22,5,-22],[-8,-23,6,20,40,17,4,-12],[13,0,-13,1,11,-2,-13,5],
             [-5,-12,-7,22,-8,-5,-15,-18],[-7,7,-3,-13,5,-16,10,-8],[0,0,0,0,0,0,0,0]]  
       
    else:
        bonus = [[[-96,-65,-49,-21],[-67,-54,-18,8],[-40,-27,-8,29],[-35,-2,13,28],[-45,-16,9,39],[-51,-44,-16,17],[-69,-50,-51,12],[-100,-88,-56,-17]],
            [[-57,-30,-37,-12],[-37,-13,-17,1],[-16,-1,-2,10],[-20,-6,0,17],[-17,-1,-14,15],[-30,6,4,6],[-31,-20,-1,1],[-46,-42,-37,-24]],
            [[-9,-13,-10,-9],[-12,-9,-1,-2],[6,-8,-2,-6],[-6,1,-9,7],[-5,8,7,-6],[6,1,-7,10],[4,5,20,-5],[18,0,19,13]],
            [[-69,-57,-47,-26],[-55,-31,-22,-4],[-39,-18,-9,3],[-23,-3,13,24],[-29,-6,9,21],[-38,-18,-12,1],[-50,-27,-24,-8],[-75,-52,-43,-36]],
            [[1,45,85,76],[53,100,133,135],[88,130,169,175],[103,156,172,172],[96,166,199,199],[92,172,184,191],[47,121,116,131],[11,59,73,78]]]
        pbonus = [[0,0,0,0,0,0,0,0],[-10,-6,10,0,14,7,-5,-19],[-10,-10,-10,4,4,3,-6,-4],[6,-2,-8,-4,-13,-12,-10,-9],[9,4,3,-12,-12,-6,13,8],
         [28,20,21,28,30,7,6,13],[0,-11,12,21,25,19,4,7],[0,0,0,0,0,0,0,0]]
    myPiece = sfBoard(pos, square[0], square[1])
    i = "PNBRQK".find(myPiece)
    if i < 0:
        return 0;
    elif i == 0:
         return(pbonus[7 - square[1]][square[0]])
    else:
        return(bonus[i-1][7 - square[1]] [min( square[0], 7-square[0] )])


##### Mobility #####
def mobility(pos, square=None):
    if square == None:
        return(sfSum(pos, mobility))
    v = 0
    b = sfBoard(pos, square[0], square[1])
    if "NBRQ".find(b) < 0:
        return(0)
    for x in range(8):
        for y in range(8):
            s2 = (x,y)
            if not mobilityArea(pos, s2):
                continue
            if b == "N" and knightAttack(pos, s2, square) and sfBoard(pos, x, y) != "Q":
                v += 1
            if b == "B" and bishopXrayAttack(pos, s2, square) and sfBoard(pos, x, y) != "Q":
                v += 1
            if b == "R" and rookXrayAttack(pos, s2, square):
                v += 1
            if b == "Q" and queenAttack(pos, s2, square):
                v += 1
    return(v)

def mobilityArea(pos, square=None):
    if square == None:
        return(sfSum(pos, mobilityArea))
    if sfBoard(pos, square[0], square[1]) == "K":
        return(0)
    if sfBoard(pos, square[0], square[1]) == "Q":
        return(0)
    if sfBoard(pos, square[0] - 1, square[1] - 1) == "p":
        return(0)
    if sfBoard(pos, square[0] + 1, square[1] - 1) == "p":
        return(0)
    if (sfBoard(pos, square[0], square[1]) == "P" and
       (rank(pos, square) < 4 or sfBoard(pos, square[0], square[1] - 1) != "-")):
        return(0)
    if blockersForKing(colorflip(pos), (square[0], 7-square[1])):
        return(0)
    return(1)

def mobilityBonus(pos, square=None, mg=True):
    if square == None:
        return(sfSum(pos, mobilityBonus)) 
    if mg:
        bonus = [
            [-62,-53,-12,-4,3,13,22,28,33],
            [-48,-20,16,26,38,51,55,63,63,68,81,81,91,98],
            [-58,-27,-15,-10,-5,-2,9,16,30,29,32,38,46,48,58],
            [-39,-21,3,3,14,22,28,41,43,48,56,60,60,66,67,70,71,73,79,88,88,99,102,102,106,109,113,116]]
    else:
        bonus = [
            [-81,-56,-30,-14,8,15,23,27,33],
            [-59,-23,-3,13,24,42,54,57,65,73,78,86,88,97],
            [-76,-18,28,55,69,82,112,118,132,142,155,165,166,169,171],
            [-36,-15,8,18,34,54,61,73,79,92,94,104,113,120,123,126,133,136,140,143,148,166,170,175,184,191,206,212]]
    i = "NBRQ".find(sfBoard(pos, square[0], square[1]))
    if i < 0:
        return(0)
    return(bonus[i][mobility(pos, square)])

def mobilityMg(pos, square=None):
    if square == None:
        return(sfSum(pos, mobilityMg))
    return(mobilityBonus(pos, square, True))    

def mobilityEg(pos, square=None):
    if square == None:
        return(sfSum(pos, mobilityEg))
    return(mobilityBonus(pos, square, False))

##### Passed Pawns #####
def passedSquare(pos, square=None):
    if square == None:
        return(sfSum(pos, passedSquare))
    for y in range(square[1]):
        if sfBoard(pos, square[0] - 1, y) == "p":
            return(0)
        if sfBoard(pos, square[0], y) == "p":
            return(0)
        if sfBoard(pos, square[0] + 1, y) == "p":
            return(0)
    return(1)

def candidatePassed(pos, square=None):
    if square == None:
        return(sfSum(pos, candidatePassed))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    ty1 = 8
    ty2 = 8
    oy = 8
    for y in range(square[1]-1, -1, -1):
        if sfBoard(pos, square[0], y) == "p":
            ty1 = y
        if (sfBoard(pos, square[0] - 1, y) == "p" or
           sfBoard(pos, square[0] + 1, y) == "p"):
            ty2 = y
    if ty1 == 8 and ty2 >= (square[1] - 1):
        return(1)
    if ty2 < (square[1] - 2) or ty1 < (square[1] - 1) :
        return(0)
    if ty2 >= square[1] and ty1 == square[1] - 1 and square[1] < 4:
        if (sfBoard(pos, square[0] - 1, square[1] + 1) == "P" and
           sfBoard(pos, square[0] - 1, square[1]) != "p" and
           sfBoard(pos, square[0] - 1, square[1] -1) != "p"):
            return(1)
        if (sfBoard(pos, square[0] + 1, square[1] + 1) == "P" and
           sfBoard(pos, square[0] + 1, square[1]) != "p" and
           sfBoard(pos, square[0] + 2, square[1] - 1) != "p"):
            return(1)
    if sfBoard(pos, square[0], square[1] -1) == "p":
        return(0)
    lever = sfBoard(pos, square[0] - 1, square[1] -1) == "p" + \
              sfBoard(pos, square[0] + 1, square[1] - 1) == "p"
    leverpush = sfBoard(pos, square[0] - 1, square[1] - 2) == "P" + \
                  sfBoard(pos, square[0] + 1, square[1] - 2) == "p"
    phalanx = sfBoard(pos, square[0] - 1, square[1]) == "P" + \
                sfBoard(pos, square[0] + 1, square[1]) == "P"
    if (lever - supported(pos, square)) > 1:
        return(0) 
    if (leverpush - phalanx) > 0:
        return(0)
    if lever > 0 and leverpush > 0:
        return(0)
    return(1)

def kingProximity(pos, square=None):
    if square == None:
        return(sfSum(pos, kingProximity))
    if not candidatePassed(pos, square):
        return(0)
    r = rank(pos, square) - 1
    if r > 2:
        w = 5 * r - 13
    else:
        w = 0
    v = 0
    if w <= 0:
        return(0)
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "k":
                v += ((min(max(abs(y - square[1] + 1),
                               abs(x - square[0])),5) * 19 // 4) << 0) * w
            if sfBoard(pos, x, y) == "K":
                v -= min(max(abs(y - square[1] + 2),
                       abs(x - square[0])),5) * 2 * w
                if square[1] > 1:
                    v -= min(max(abs(y - square[1] + 2),
                               abs(x - square[0])),5) * w
    return(v)

def passedBlock(pos, square=None):
    if square == None:
        return(sfSum(pos, passedBlock))
    if not candidatePassed(pos, square):
        return(0)
    if rank(pos, square) < 4:
        return(0)
    if sfBoard(pos, square[0], square[1] - 1) != "-":
        return(0)
    r = rank(pos, square) - 1
    if r > 2:
        w = 5 * r - 13
    else:
        w = 0
    pos2 = colorflip(pos)
    defended = 0
    unsafe = 0
    wunsafe = 0
    defended1 = 0
    unsafe1 = 0
    for y in range(square[1]-1, -1, -1):
        if attack(pos, (square[0], y)):
            defended += 1
        if attack(pos2, (square[0], 7-y)):
            unsafe += 1
        if attack(pos2, (square[0]-1,7-y)):
            wunsafe += 1
        if attack(pos2, (square[0]+1,7-y)):
            wunsafe += 1
        if y == square[1] - 1:
            defended1 += defended
            unsafe1 = unsafe
    for y in range(square[1]+1, 8):
        if sfBoard(pos, square[0], y) == "R" or sfBoard(pos, square[0], y) == "Q":
            defended1 = square[1]
            defended = square[1]
        if sfBoard(pos, square[0], y) == "r" or sfBoard(pos, square[0], y) == "q":
            unsafe1 = square[1]
            unsafe = square[1]
            
    if unsafe == 0 and wunsafe == 0:
        k = 35
    elif unsafe == 0:
        k = 20
    elif unsafe1 == 0:
        k = 9
    else:
        k = 0
    return(k * w)

def passedFile(pos, square=None):
    if square == None:
        return(sfSum(pos, passedFile))
    if not candidatePassed(pos, square):
        return(0)
    myFile = sfFile(pos, square)
    return(min(myFile - 1, 8 - myFile))

def passedRank(pos, square=None):
    if square == None:
        return(sfSum(pos, passedRank))
    if not candidatePassed(pos, square):
        return(0)
    return(rank(pos, square)-1)

def passedMg(pos, square=None):
    if square == None:
        return(sfSum(pos, passedMg))
    if not candidatePassed(pos, square):
        return(0)
    v = 0
    v += [0,10,17,15,62,168,276][passedRank(pos, square)]
    v += passedBlock(pos, square)
    if (not passedSquare(pos, (square[0], square[1]-1)) or 
       sfBoard(pos, square[0], square[1]-1).upper() == "P"):
        v = (v // 2) << 0
    v -= 11 * passedFile(pos, square)
    return(v)

def passedEg(pos, square=None):
    if square == None:
        return(sfSum(pos, passedEg))
    if not candidatePassed(pos, square):
        return(0)
    v = 0
    v += kingProximity(pos, square)
    v += [0,28,33,41,72,177,260][passedRank(pos, square)]
    v += passedBlock(pos, square)
    if (not passedSquare(pos, (square[0], square[1]-1)) or
      sfBoard(pos, square[0], square[1]-1).upper() == "P"):
        v = (v//2) << 0
    v -= 8 * passedFile(pos, square)
    return(v)
        
##### Space #####
def spaceArea(pos, square=None):
    if square == None:
        return(sfSum(pos, spaceArea))
    v = 0
    myRank = rank(pos, square)
    myFile = sfFile(pos, square)
    if ((myRank >= 2 and myRank <=4 and myFile >= 3 and myFile <=6) and
      sfBoard(pos, square[0], square[1]) != "P" and
      sfBoard(pos, square[0] - 1, square[1] - 1) != "p" and
      sfBoard(pos, square[0] + 1, square[1] - 1) != "p"):
        v += 1
        if ((sfBoard(pos, square[0], square[1] - 1) == "P" or
          sfBoard(pos, square[0], square[1] - 2) == "P" or
          sfBoard(pos, square[0], square[1] - 3) == "P") and
          not attack(colorflip(pos), (square[0], 7-square[1]))):
            v += 1
    return(v)

def space(pos, square=None):
    if nonPawnMaterial(pos) + nonPawnMaterial(colorflip(pos)) < 12222:
        return(0)
    weight = -1
    for x in range(8):
        for y in range(8):
            if "PNBRQK".find(sfBoard(pos, x, y)) >= 0:
                weight += 1
    return((spaceArea(pos, square) * weight * weight//16) << 0)



##### Threats #####
def safePawn(pos, square=None):
    if square == None:
        return(sfSum(pos, safePawn))
    if sfBoard(pos, square[0], square[1]) != "P":
        return(0)
    if attack(pos, square):
        return(1)
    if not attack(colorflip(pos), (square[0], 7-square[1])):
        return(1)
    return(0)       

def threatSafePawn(pos, square=None):
    if square == None:
        return(sfSum(pos, threatSafePawn))
    if "nbrq".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    if not pawnAttack(pos, square):
        return(0)
    if (safePawn(pos, (square[0] - 1, square[1] + 1)) or
       safePawn(pos, (square[0] + 1, square[1] + 1))):
        return(1)
    return(0)

def weakEnemies(pos, square=None):
    if square == None:
        return(sfSum(pos, weakEnemies))
    if "pnbrqk".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    if sfBoard(pos, square[0] - 1, square[1] - 1) == "p":
        return(0)
    if sfBoard(pos, square[0] + 1, square[1] - 1) == "p":
        return(0)
    if not attack(pos, square):
        return(0)
    if (attack(pos, square) <= 1 and
       attack(colorflip(pos), (square[0], 7 - square[1])) > 1):
        return(0)
    return(1)
        
def minorThreat(pos, square=None):
    '''Ian MacKaye was right.'''
    if square == None:
        return(sfSum(pos, minorThreat))
    theirPiece = "pnbrqk".find(sfBoard(pos, square[0], square[1]))
    if theirPiece < 0:
        return(0)
    if not knightAttack(pos, square) and not bishopXrayAttack(pos, square):
        return(0)
    if (sfBoard(pos, square[0] - 1, square[1] - 1) == "p" or
     not (sfBoard(pos, square[0] - 1, square[1] - 1) == "p" or
     sfBoard(pos, square[0] + 1, square[1] - 1) == "p" or
     (attack(pos, square) <= 1 and 
       attack(colorflip(pos), (square[0], 7-square[1])) > 1)) and
     not weakEnemies(pos, square)):
        return(0)
    return(theirPiece + 1)

def rookThreat(pos, square=None):
    if square == None:
        return(sfSum(pos, rookThreat))
    theirPiece = "pnbrqk".find(sfBoard(pos, square[0], square[1]))
    if theirPiece < 0:
        return(0)
    if not weakEnemies(pos, square):
        return(0)
    if not rookXrayAttack(pos, square):
        return(0)
    return(theirPiece + 1)

def hanging(pos, square=None):
    if square == None:
        return(sfSum(pos, hanging))
    if not weakEnemies(pos, square):
        return(0)
    if sfBoard(pos, square[0], square[1]) != "p" and attack(pos, square) > 1:
        return(1)
    if not attack(colorflip(pos), (square[0], 7-square[1])):
        return(1)
    return(0)

def kingThreat(pos, square=None):
    if square == None:
        return(sfSum(pos, kingThreat))
    if "pnbrq".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    if not weakEnemies(pos, square):
        return(0)
    if not kingAttack(pos, square):
        return(0)
    return(1)

def pawnPushThreat(pos, square=None):
    if square == None:
        return(sfSum(pos, pawnPushThreat))
    if "pnbrqk".find(sfBoard(pos, square[0], square[1])) < 0:
        return(0)
    for ix in range(-1, 2, 2):
        if (
          sfBoard(pos, square[0] + ix, square[1] + 2) == "P" and
          sfBoard(pos, square[0] + ix, square[1] + 1) == "-" and
          sfBoard(pos, square[0] + ix - 1, square[1]) != "p" and
          sfBoard(pos, square[0] + ix + 1, square[1]) != "p" and
          (attack(pos, (square[0]+ix, square[1]+1)) or
            not attack(colorflip(pos), (square[0]+ix, 6-square[1])))
          ):
            return(1)
        if (
          square[1] == 3 and
          sfBoard(pos, square[0] + ix, square[1] + 3) == "P" and
          sfBoard(pos, square[0] + ix, square[1] + 2) == "-" and
          sfBoard(pos, square[0] + ix, square[1] + 1) == "-" and
          sfBoard(pos, square[0] + ix - 1, square[1]) != "p" and
          sfBoard(pos, square[0] + ix + 1, square[1]) != "p" and
          (attack(pos, (square[0]+ix, square[1]+1)) or
            not attack(colorflip(pos), (square[0]+ix, 6-square[1])))
          ):
            return(1)
    return(0)

def sliderOnQueen(pos, square=None):
    if square == None:
        return(sfSum(pos, sliderOnQueen))
    pos2 = colorflip(pos)
    if queenCount(pos2) != 1:
        return(0)
    if sfBoard(pos, square[0] - 1, square[1] - 1) == "p":
        return(0)
    if sfBoard(pos, square[0] + 1, square[1] - 1) == "p":
        return(0)
    if attack(pos, square) <= 1:
        return(0)
    if not mobilityArea(pos, square):
        return(0)
    diagonal = queenAttackDiagonal(pos2, (square[0], 7-square[1]))
    if (not diagonal and
      rookXrayAttack(pos, square) and
      queenAttack(pos2, (square[0], 7-square[1]))):
        return(1)
    return(0)

def knightOnQueen(pos, square=None):
    if square == None:
        return(sfSum(pos, knightOnQueen))
    pos2 = colorflip(pos)
    qx = -1
    qy = -1
    for x in range(8):
        for y in range(8):
            if sfBoard(pos, x, y) == "q":
                if qx >= 0 or qy >= 0:
                    return(0)
                qx = x
                qy = y
    if queenCount(pos2) != 1:
        return(0)
    if sfBoard(pos, square[0] - 1, square[1] - 1) == "p":
        return(0)
    if sfBoard(pos, square[0] + 1, square[1] - 1) == "p":
        return(0)
    if attack(pos, square) <= 1 and attack(pos2, (square[0], 7-square[1])) > 1:
        return(0)
    if not mobilityArea(pos, square):
        return(0)
    if not knightAttack(pos, square):
        return(0)
    if abs(qx-square[0] == 2) and abs(qy-square[1]) == 1:
        return(1)
    if abs(qx-square[0] == 1) and abs(qy-square[1]) == 2:
        return(1)
    return(0)

def restricted(pos, square=None):
    if square == None:
        return(sfSum(pos, restricted))
    if attack(pos, square) == 0:
        return(0)
    pos2 = colorflip(pos)
    if not attack(pos2, (square[0], 7-square[1])):
        return(0)
    if pawnAttack(pos2, (square[0], 7-square[1])) > 0:
        return(0)
    if attack(pos2, (square[0], 7-square[1])) > 1 and attack(pos, square) == 1:
        return(0)
    return(1)

def threatsMg(pos):
    v = 0
    v += 69 * hanging(pos)
    if kingThreat(pos) > 0:
        v += 24
    v += 48 * pawnPushThreat(pos)
    v += 173 * threatSafePawn(pos)
    v += 59 * sliderOnQueen(pos)
    v += 16 * knightOnQueen(pos)
    v += 7 * restricted(pos)
    for x in range(8):
        for y in range(8):
            s = (x,y)
            v += [0,6,59,79,90,79,0][minorThreat(pos, s)]
            v += [0,3,38,38,0,51,0][rookThreat(pos, s)]
    return(v)

def threatsEg(pos):
    v = 0
    v += 36 * hanging(pos)
    if kingThreat(pos) > 0:
        v += 89
    v += 39 * pawnPushThreat(pos)
    v += 94 * threatSafePawn(pos)
    v += 18 * sliderOnQueen(pos)
    v += 12 * knightOnQueen(pos)
    v += 7 * restricted(pos)
    for x in range(8):
        for y in range(8):
            s = (x,y)
            v += [0,32,41,56,119,161,0][minorThreat(pos, s)]
            v += [0,44,71,61,38,38,0][rookThreat(pos, s)]
    return(v)

import time
timeList = []
for i in range(10):
    t1 = time.time()
    mainEvaluation(pos)
    timeList.append(time.time() - t1)

print(sum(timeList)/len(timeList))
