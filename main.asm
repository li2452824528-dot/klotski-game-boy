; Members Zewan Lyu(999019888), Zeyan YIN(999020183), Weihan Li(999019797), Xiang Li(999019771)

INCLUDE "hardware.inc"
INCLUDE "data.inc"

SECTION "Header", ROM0[$100]
  jp EntryPoint

  ds $150 - @, 0

EntryPoint:
  call WaitVBlank
  ld a, 0
  ld [rLCDC], a

  ld a,%11100100 ; set palette
  ld [rBGP], a
  ld [rOBP0], a
  call InitializeGlobalVariables
  call InitializeLocalVariables
  call  CopyTileDataToVRAM
  call   CopyBGToShadowSCRN 
  call   CopyShadowSCRNToSCRN 
  ld    hl, _OAMRAM
  call  ResetOAM 
  call InitializeObjects 
  call stateTransition 



menuEntryPoint: 
  call matrixInitialize 
  ld de, menu 
  call loadingProcess
menuLoop: 
  call readKeys 
  jp stateChangeDetectForMenu
menuBack: 
  call mouse 
  call LevelSelection 
  call WaitVBlank 
  call CopyShadowOAMtoOAM 
  call ModifySCRNForCounterAndLevel 
  jp menuLoop 


selectingEntryPoint: 
  ld hl, _OAMRAM 
  call ResetOAM
  call InitializeLocalVariables
  call matrixInitialize 
  ld a, [LevelCounter] 
  add a, a 
  ld d, 0 
  ld e, a 
  ld hl, levelTable 
  add hl, de 
  ld a, [hl+] 
  ld h, [hl] 
  ld l, a 
  ld d, h 
  ld e, l 
  call loadingProcess 
  ld a, STATE2
  ld [stateOffSet], a 
  jp stateTransition 

selectingLoop:
  call readKeys
  jp stateChangeDetectForSelecting
selectingBack: 
  call selectingDirection 
  ;call chooseRight 
  call matricesToShadowSCRN 
  call setInitialAddressAndHeight 
  call WaitVBlank 
  call ModifySCRNSelectively 
  jp selectingLoop


victoryEntryPoint: 
  call matrixInitialize 
  ld de, victory 
  call loadingProcess 
victoryLoop: 
  call readKeys 
  jp stateChangeDetectForVictory 
victoryBack: 
  call WaitVBlank 
  jp victoryLoop 



stateChangeDetectForVictory: 
  ld a, [current] 
  bit 0, a 
  jr z, .skipBackToMenu 
  ld a, STATE0
  ld [stateOffSet], a 
  jp stateTransition 
.skipBackToMenu: 
  jp victoryBack 



movingLoop: 
  call readKeys 
  jp stateChangeDetectForMoving
movingBack: 
  call movingDirection 
  ;call moveDown 
  call matricesToShadowSCRN 
  call setInitialAddressAndHeight 
  call WaitVBlank 
  call ModifySCRNSelectively 
  call displayStepCounter 
  jp movingLoop


displayStepCounter: 
  ld de, _SCRN0 + 15  
  ld hl, stepCounterArray + STEPCHANGE
  ld a, [hl] 
  add a, 75
  ld [de], a 
  inc de 
  dec hl 
  ld a, [hl] 
  add a, COUNTERLINE
  ld [de], a 
  inc de 
  dec hl 
  ld a, [hl] 
  add a, COUNTERLINE
  ld [de], a 
  inc de 
  dec hl 
  ld a, [hl] 
  add a, COUNTERLINE
  ld [de], a 
  ret  
  


stepCounter: 
  ld hl, stepCounterArray + STEPCHANGE
  ld a, [hl] 
  or a 
  ret nz 
  ld hl, stepCounterArray
.loop:  
  inc [hl] 
  ld a, [hl] 
  cp a, TRIGH
  ret nz 
  ld a, 0 
  ld [hl], a 
  inc hl 
  jr .loop

ModifySCRNForCounterAndLevel:  
  ld hl, _SCRN0 + 3 
  ld a, [LevelCounter]
  add a, 76 
  ld [hl], a 
  ret  


LevelSelection: 
  ld b, 0 
  ld a, [mouseRow]
  or a    
  jr z, .skip
  ld a, ROWCHANGE
  ld b, a 
.skip: 
  ld a, [mouseCol] 
  add a, b 
  ld [LevelCounter], a 
  ret   


stateChangeDetectForSelecting: 
  ;Down Up Left Right Start Select B A 
  ld a, [current] 
  bit 0, a 
  jr z, .skipMoving 
  ld a, 3
  ld [stateOffSet], a
  jr .nextTransition
.skipMoving: 
  ld a, [current]
  bit 1, a 
  jr z, .skipMenu
  ld a, STATE0
  ld [stateOffSet], a  
  jr .nextTransition
.skipMenu: 
  ld a, [oldMatrix + OLDOFFSET]
  xor a, %01000100
  jr nz, .skipWin
  ld a, ROWCHANGE
  ld [stateOffSet], a 
  jr .nextTransition 
.skipWin: 
  jp selectingBack 
.nextTransition: 
  jp stateTransition  


  
stateChangeDetectForMoving: 
  ;Down Up Left Right Start Select B A 
  ld a, [current] 
  bit 0, a 
  jr z, .skipSelecting
  ld a, STATE2
  ld [stateOffSet], a
  jr .nextTransition
.skipSelecting: 
  ld a, [current] 
  bit 1, a 
  jr z, .skipMenu
  ld a, STATE0
  ld [stateOffSet], a 
  jr .nextTransition
.skipMenu: 
  jp movingBack 
.nextTransition: 
  jp stateTransition  


stateChangeDetectForMenu: 
  ld a, [current] 
  bit 0, a 
  jp z, menuBack 
  ld a, STATE1
  ld [stateOffSet], a 
  jp stateTransition 



stateTransition: 
;For changing the state  
  ld hl, stateTable 
  ld a, [stateOffSet]
  add a, a 
  ld c, a 
  ld b, 0 
  add hl, bc 
  ld c, [hl]
  inc hl 
  ld b, [hl] 
  ld h, b 
  ld l, c 
  jp hl 



loadingProcess: 
  call matrixLoad 
  ld a, 0 
  ld [rLCDC], a 
  call displayMatrix 
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000 
  ld [rLCDC], a 
  call WaitVBlank
  ret  


selectingDirection: 
  ld a, [current]
  and a, %11110000
  cp a, %00010000
  call z, chooseRight 
  cp a, %00100000
  call z, chooseLeft 
  cp a, %10000000
  call z, chooseDown
  cp a, %01000000
  call z, chooseUp 

  ret   


movingDirection: 
  ld a, [current]
  and a, %11110000
  cp a, %00010000
  call z, moveRight 
  cp a, %00100000
  call z, moveLeft 
  cp a, %10000000
  call z, moveDown
  cp a, %01000000
  call z, moveUp  

  ret 


moveUp: 
  ld hl, oldMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix

  ld d, h 
  ld e, l 
.smallloop10: 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  ld a, [hl] 
  bit 2, a 
  jr nz, .smallloop10 

  or a 
  ret nz ; The label where nothing is done

  ld a, [de] 
  and a, %00010000
  jr nz, .toMove   ; directly move if its width smaller than 2 else we detect the next level  

  inc hl  
  ld a, [hl]  
  
  or a
  ret nz ; do nothing 

.toMove: 
  ld a, 2
  ld [moving], a 
  ; We only need move the whole block to one of four direction 
  call moveBlock 
  ret  



moveDown: 
  ld hl, oldMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix

  ld d, h 
  ld e, l 
.smallloop10: 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl] 
  bit 2, a 
  jr nz, .smallloop10 

  or a 
  ret nz ; The label where nothing is done

  ld a, [de] 
  and a, %00010000
  jr nz, .toMove   ; directly move if its width smaller than 2 else we detect the next level  

  inc hl  
  ld a, [hl]  
  
  or a
  ret nz ; do nothing 

.toMove: 
  ld a, 1
  ld [moving], a 
  ; We only need move the whole block to one of four direction 
  call moveBlock 
  ret  



moveLeft: 
  ld hl, oldMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix

  ld d, h 
  ld e, l 
.smallloop10: 
  dec hl 
  ld a, [hl] 
  bit 2, a 
  jr nz, .smallloop10 

  or a 
  ret nz ; The label where nothing is done

  ld a, [de] 
  and a, %11110000
  cp a, %00110000 
  jr c, .toMove   ; directly move if its height smaller than 2 else we detect the next level  

  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl]  
  
  or a
  ret nz ; do nothing 

.toMove: 
  ld a, STATE3
  ld [moving], a 
  ; We only need move the whole block to one of four direction 
  call moveBlock 
  ret  




moveRight: 
  ld hl, oldMatrix 
  ld b, STATE0
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix

  ld d, h 
  ld e, l 
.smallloop10: 
  inc hl 
  ld a, [hl] 
  bit 2, a 
  jr nz, .smallloop10 

  or a 
  ret nz ;

  ld a, [de] 
  and a, %11110000
  cp a, %00110000 
  jr c, .toMove   ; directly move if its height smaller than 2 else we detect the next level  
  
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl] 
  or a
  ret nz; do nothing 

.toMove: 
  ld a, 4
  ld [moving], a 
  ; We only need move the whole block to one of four direction 
  call moveBlock 
  ret   





moveBlock: 
  ; de the address of top left element of the whole block in the old matrix
  ; hl: the corresponding address in the new matrix
  ; moving(WRAM): the direction to move 
  ; 0: default
  ; 1: down 
  ; 2: up 
  ; 3: left 
  ; 4: right 
  call stepCounter 
  ld hl, newMatrix
  ld a, [selecting] 
  ld c, a 
  ld b, 0 
  add hl, bc ;position in new matrix 
  ld a, [moving] ;set the offset

.downSet: 
  dec a 
  jr nz, .upSet
  ld a, [selecting] 
  add a, NEXT
  ld [selecting], a 
  ld b, 0 
  ld c, NEXT
  jr .finishSet
.upSet: 
  dec a 
  jr nz, .leftSet
  ld a, [selecting] 
  sub a, NEXT
  ld [selecting], a 
  ld b, -1
  ld c, 250
  jr .finishSet
.leftSet:
  dec a 
  jr nz, .rightSet
  ld a, [selecting] 
  dec a 
  ld [selecting], a 
  ld b, LEFTSET
  ld c, LEFTSET
  jr .finishSet 

.rightSet: 
  dec a 
  ld a, [selecting] 
  inc a 
  ld [selecting], a 
  ld b, 0
  ld c, 1 

.finishSet:
  ld a, 0 
  ld [moving], a ;restore moving
  
  ;we let bc be the offset 

  push hl 
  ld a, 0 
  ld [hl], a         

  inc hl 
  ld a, [hl] 
  and a, %00000001
  jr z, .myskip11

  ld a, 0 
  ld [hl], a 
.myskip11: 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl] 
  and a, %00000011
  xor a, %00000010
  jr nz, .myskip12
  ld a, 0 
  ld [hl], a 
.myskip12: 
  inc hl 
  ld a, [hl]
  and a, %00000011
  xor a, %00000011
  jr nz, .myskip13 
  ld a, 0 
  ld [hl], a 


.myskip13: 
  pop hl 

 
  ld a, [de]
  push hl 
  add hl, bc         
  ld [hl], a ;First corner
  pop hl 

  inc de 
  inc bc 
  ld a, [de] 
  and a, %00000001
  jr z, .myskip21

  ld a, [de] 
  push hl 
  add hl, bc 
  ld [hl], a 
  pop hl 
.myskip21: 
  inc de 
  inc de 
  inc de 
  inc de 
  inc de 
  inc bc 
  inc bc 
  inc bc 
  inc bc 
  inc bc 
  ld a, [de] 
  and a, %00000011
  xor a, %00000010
  jr nz, .myskip22 
  ld a, [de] 
  push hl 
  add hl, bc 
  ld [hl], a
  pop hl  
.myskip22: 
  inc de 
  inc bc 
  ld a, [de]
  and a, %00000011
  xor a, %00000011
  ret nz 
  ld a, [de]
  push hl 
  add hl, bc  
  ld [hl], a 
  pop hl 
  ret    
  



unselectedBlockDetect: 
  ; decide if the current byte is not empty and is unselected
  ; hl: address of the byte 
  ;  
  ld a, [hl] 
  and a, %11110000
  cp a, %00010000
  jr nc, .notEmpty
  ld a, 0
  ret 
.notEmpty: 
  ld a, [hl] 
  bit 2, a 
  jr z, .unselected 
  ld a, 0 
  ret 
.unselected: 
  ld a, 1 
  ret 



chooseUp:

  call specialCaseDetectTopLeft 
  ld a, TLEFT
  cp a, c 
  jr z, .jump 
  call specialCaseDetectTopRight 
  ld a, TRIGH
  cp a, c 
  jr z, .jump 
  ; b traverseRecord 1 
  ; c traverseRecord 2  
  ld hl, newMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix


  ld d, h 
  ld e, l 
  ld c, 0
.smallloop1: 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  inc b   ; b marks the distance 
  call unselectedBlockDetect 
  or a 
  jr z, .smallloop1    

  ld h, d 
  ld l, e 
  inc hl 
.smallloop2: 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl  
  inc c 
  call unselectedBlockDetect
  or a  
  jr z, .smallloop2 


  ld a, [de] 
  and a, %00010000 ; a is not zero if its width smaller than 2
  or a   
  jr nz, .changeSelection1
  ld a, b 
  cp a, c ; flag set 1 if b is smaller than c 
  jr nc, .changeSelection2

.changeSelection1:
  ;focus on b
  ;We need sub b*6 
  ld c, b
  ld b, 0  
  ld h, 0 
  ld l, 0 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc
  call substraction   
.jump: 
  call changeMatrixSeletionState
  ret 

.changeSelection2: 
  ;focus on c 
  ;We need sub c*6 and increase 1 
  ld b, 0 
  ld h, 0 
  ld l, 0 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc
  call substraction  
  inc hl 
  call changeMatrixSeletionState 
  ret 



chooseDown:
  call specialCaseDetectBottomLeft 
  ld a, BLEFT
  cp a, c 
  jr z, .jump 
  call specialCaseDetectBottomRight 
  ld a, BRIGHT
  cp a, c 
  jr z, .jump 
  ; b traverseRecord 1 
  ; c traverseRecord 2  
  ld hl, newMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix


  ld d, h 
  ld e, l 
  ld c, 0
.smallloop1: 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc b   ; b marks the distance 
  call unselectedBlockDetect 
  or a 
  jr z, .smallloop1    

  ld h, d 
  ld l, e 
  inc hl 
.smallloop2: 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl  
  inc c 
  call unselectedBlockDetect
  or a  
  jr z, .smallloop2 


  ld a, [de] 
  and a, %00010000 ; a is not zero if its width smaller than 2
  or a   
  jr nz, .changeSelection1
  ld a, b 
  cp a, c ; flag set 1 if b is smaller than c 
  jr nc, .changeSelection2

.changeSelection1:
  ;focus on b
  ;We need to add b*6
  ld h, d 
  ld l, e   
  ld c, b 
  ld b, 0
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc  
.jump: 
  call changeMatrixSeletionState
  ret 

.changeSelection2: 
  ;focus on c 
  ;We need add c*6 + 1
  ld h, d 
  ld l, e 
  ld b, 0 
  inc hl 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  add hl, bc 
  call changeMatrixSeletionState 
  ret 



chooseLeft:
  call specialCaseDetectTopLeft 
  ld a, TLEFT
  cp a, c 
  jr z, .jump 
  call specialCaseDetectBottomLeft 
  ld a, BLEFT
  cp a, c 
  jr z, .jump 
  ; b traverseRecord 1 
  ; c traverseRecord 2  
  ld hl, newMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the selected element


  ld d, h 
  ld e, l 
  ld c, 0
.smallloop1: 
  dec hl 
  inc b   ; b marks the number
  call unselectedBlockDetect 
  or a 
  jr z, .smallloop1    

  ld h, d 
  ld l, e 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
.smallloop2: 
  dec hl 
  inc c 
  call unselectedBlockDetect
  or a  
  jr z, .smallloop2 


  ld a, [de] 
  and a, %11110000
  cp a, %00110000 ; flag set 1 if its height smaller than 2
  jr c, .changeSelection
  ld a, b 
  cp a, c ; carry flag set 1 if b is smaller than c 
  jr c, .changeSelection  
  ld a, c 
  sub a, NEXT
  ld b, a ; change the value of b such that we operate on next line 

.changeSelection:
  ;focus on b
  ;For first line we need to substract b from de and store it in hl
  ;Here we cannot easily substract b from de since b might be negative 
  ld a, b 
  call loadIntoPairRegister 
  call substraction ; which get de - hl which modify hl 
.jump: 
  call changeMatrixSeletionState
  ret 



loadIntoPairRegister: 
  ; load a into hl
  ; For 2's complement decode method, that is, a ranging from -128 to 127 
  bit 7, a 
  jr z, .skkip 
  cpl 
  inc a ; now a is positive  
  ld l, a 
  ld h, 0 
  call getInvert 
  ret   

.skkip: 
  ld l, a 
  ld h, 0 
  ret 


specialCaseDetectBottomRight:
  ; if detected c is set to 34
  ld b, 0  
  ld c, SCASE
  ld hl, newMatrix 
  add hl, bc 
  ld a, [hl+] 
  xor a, %00010100
  ret nz 
  ld a, [hl+] 
  or a, a 
  ret nz  
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl+] 
  or a, a
  ret nz 
  ld a, [hl] 
  xor a, %00010000 
  ret nz 
  ld b, 0 
  ld c, SCASE
  ld hl, newMatrix 
  add hl, bc 
  ld d, h 
  ld e, l 
  ld b, 0 
  ld c, BRIGHT
  ld hl, newMatrix 
  add hl, bc 
  ret  


specialCaseDetectTopRight:
  ; if detected then c is set to 10 
  ld b, 0   
  ld c, 9
  ld hl, newMatrix 
  add hl, bc 
  ld a, [hl+] 
  or a, a  
  ret nz 
  ld a, [hl+] 
  xor a, %00010000
  ret nz  
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl+] 
  xor a, %00010100
  ret nz 
  ld a, [hl] 
  or a, a 
  ret nz 
  ld b, 0 
  ld c, TRIGHT
  ld hl, newMatrix 
  add hl, bc 
  ld d, h 
  ld e, l 
  ld b, 0 
  ld c, 10 
  ld hl, newMatrix 
  add hl, bc 
  ret  


specialCaseDetectTopLeft:
  ; if detected then c is set to 8
  ld b, 0   
  ld c, 7
  ld hl, newMatrix 
  add hl, bc 
  ld a, [hl+] 
  xor a, %00010000  
  ret nz 
  ld a, [hl+] 
  or a, a 
  ret nz  
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl+] 
  or a, a 
  ret nz 
  ld a, [hl] 
  xor a, %00010100
  ret nz 
  ld b, 0 
  ld c, 14
  ld hl, newMatrix 
  add hl, bc 
  ld d, h 
  ld e, l 
  ld b, 0 
  ld c, TLEFT - 1
  ld hl, newMatrix 
  add hl, bc
  ld c, TLEFT  
  ret  

specialCaseDetectBottomLeft:
  ; if detected then c is set to 31
  ld b, 0   
  ld c, 25
  ld hl, newMatrix 
  add hl, bc 
  ld a, [hl+] 
  or a, a  
  ret nz 
  ld a, [hl+] 
  xor a, %00010100
  ret nz  
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl+] 
  xor a, %00010000
  ret nz 
  ld a, [hl] 
  or a, a 
  ret nz 
  ld b, 0 
  ld c, OLDOFFSET
  ld hl, newMatrix 
  add hl, bc 
  ld d, h 
  ld e, l 
  ld b, 0 
  ld c, BLEFT
  ld hl, newMatrix 
  add hl, bc 
  ret  

  

chooseRight:
  call specialCaseDetectTopRight 
  ld a, TRIGH
  cp a, c 
  jr z, .jump 
  call specialCaseDetectBottomRight 
  ld a, BRIGHT
  cp a, c 
  jr z, .jump 

  ; b traverseRecord 1 
  ; c traverseRecord 2  
  ld hl, newMatrix 
  ld b, 0  
  ld a, [selecting] 
  ld c, a 
  add hl, bc ; current coordinate of the matrix

  ld d, h 
  ld e, l 
  ld c, 0
.smallloop1: 
  inc hl 
  inc b   ; b marks the number
  call unselectedBlockDetect 
  or a 
  jr z, .smallloop1    


  ld h, d 
  ld l, e 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl  
.smallloop2: 
  inc hl 
  inc c 
  call unselectedBlockDetect
  or a  
  jr z, .smallloop2 


  ld a, [de] 
  and a, %11110000
  cp a, %00110000 ; flag set 1 if its height smaller than 2
  jr c, .changeSelection
  ld a, b 
  cp a, c ; flag set 1 if b is smaller than c 
  jr c, .changeSelection  
  ld a, c 
  add a, NEXT
  ld b, a ; change the value of b such that we operate on next line 

.changeSelection:
  ;focus on b  
  ld h, d 
  ld l, e 
  ld c, b ; now b is destroyed
  ld b, 0 
  add hl, bc ; address of first selected block 
.jump: 
  call changeMatrixSeletionState
  ret 

getInvert: 
  ; hl to get invert 
  ld a, h 
  cpl 
  ld h, a 
  ld a, l 
  cpl 
  ld l, a 
  inc hl 
  ret   


substraction: 
  ; How to substract two pair register? Maybe this works 
  ;de - hl 
  call getInvert 
  add hl, de 
  ret  



changeMatrixSeletionState: 
  ;de: source byte 
  ;hl: destination byte
  ld a, [hl] ; information of that block  
  and a, %11110000
  xor a, %01010000 ; a = 0 if we meet a wall
  jp z, .myskip4 ; to somewhere we do nothing
  ld a, [hl]  
  and a, %00000011
  inc a 
  call blockJump

  
  push hl 
  call substraction 
  ;hl now is the difference we need to 
  ;selecting - hl
  call getInvert ; change to selecting + hl
  ld a, [selecting] 
  ld b, 0 
  ld c, a 
  add hl, bc ; final num 
  ld a, l  

  ld [selecting], a 
  pop hl 


  ld a, [hl] 
  add a, %00000100
  ld [hl], a 
  ;We need draw all four corners
  inc hl 
  ld a, [hl]
  and a, %00000001 
  jr z, .myskip1
  ld a, [hl] 
  add a, %00000100
  ld [hl], a 
.myskip1: 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl] 
  and a, %00000011
  xor a, %00000010
  jr nz, .myskip2 
  ld a, [hl]
  add a, %00000100
  ld [hl], a 
.myskip2: 
  inc hl 
  ld a, [hl] 
  and a, %00000011
  xor a, %00000011 ; 0 if a stands for bottom right
  jr nz, .myskip3
  ld a, [hl] 
  add a, %00000100
  ld [hl], a 
.myskip3: ; unselect block 
  ; de the source position 
  ; unselect the block
  ;
  ;
  ld h, d 
  ld l, e 
  ld a, [hl] ; information of that block  
   
  sub a, %00000100
  ld [hl], a 
  ;We need draw all four coners
  inc hl 
  ld a, [hl]
  and a, %00000001 
  jr z, .myskip5
  ld a, [hl] 
  sub a, %00000100
  ld [hl], a 
.myskip5: 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  inc hl 
  ld a, [hl]
  and a, %00000011 
  xor a, %00000010
  jr nz, .myskip6
  ld a, [hl]
  sub a, %00000100
  ld [hl], a 
.myskip6: 
  inc hl 
  ld a, [hl] 
  and a, %00000011
  xor a, %00000011 ; 0 if a stands for bottom right
  jr nz, .myskip4
  ld a, [hl] 
  sub a, %00000100
  ld [hl], a 
  ;
  ;
  ;
.myskip4:
  ret 



   
blockJump: 
  ;decide how to jump according to the last two bits
  ;hl is the address
  ;
  dec a 
  ret z 
  dec a 
  jr z, .jump1 
  dec a 
  jr z, .jump2 
  dec a 
  jr z, .jump3 
.jump1: 
  dec hl 
  ret 
.jump2: 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  ret 
.jump3: 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  dec hl 
  ret 




WaitVBlank:
  ld a, [rLY]
  cp 144
  jr nz, WaitVBlank
  ret




ResetOAM:
; input: HL: location of OAM or Shadow OAM
  ld b,40*4
  ld a,0
.loop1:
  ld [hl],a
  inc hl
  dec b
  jr nz,.loop1
  ret

CopyTileDataToVRAM:
  ld de, Tiles
  ld hl, _VRAM
  ld bc, TilesEnd - Tiles
.copy1:
  ld a,[de]
  inc de
  ld [hl],a
  inc hl
  dec bc
  ld a,b
  or c
  jr nz, .copy1
  ret


RandomByte:
  ld a,[rDIV]
  xor b
  xor c
  xor d
  xor e
  xor h
  xor l
  xor [hl]
  ret


CopyMemory:
  ; input:
  ; de : source
  ; hl : destination
  ; bc : how many bytes
.copy2:
  ld a,[de]
  inc de
  ld [hl],a
  inc hl
  dec bc
  ld a,b
  or c
  jr nz, .copy2
  ret

matrixLoad:
  ; input:
  ; de : source
  ; hl : destination
  ld hl, newMatrix
  ld b, MSIZE
.copy3:
  ld a, [de]
  ld c, a 
  bit 2, a   
  call nz, selectingSet
  ld a, c  
  inc de 
  ld [hl], a
  inc hl
  dec b
  jr nz, .copy3
  ret

selectingSet: 
  ld a, [selecting]
  or a   
  ret nz 
  ld a, MSIZE
  sub a, b 
  ld [selecting], a
  ret


CopyShadowSCRNToSCRN: 
  ld de, shadowSCRN
  ld hl, _SCRN0 
  ld bc, BackgroundEnd - Background 
  call CopyMemory 
  ret


CopyBGToShadowSCRN:
  ld de, Background
  ld hl, shadowSCRN 
  ld bc, BackgroundEnd - Background
  call CopyMemory
  ret

UnitDraw: 
  ; This function works well. 
  ; de: unit address 
  ; hl: one adress in the buffer shadowSCRN
  ; b indicate whether reverse the color
  ; 1: reverse 0: not reverse 
  ; 35 is the number of tiles(unselected) for blocks 
  ld c, CHANGENUMBER
  dec b 
  jr z, .skip1
  ld c, 0 
.skip1: 
  ld a, [de] 
  inc de 
  add a, c 
  ld [hl+], a 
  ld a, [de] 
  inc de 
  add a, c 
  ld [hl+], a 
  ld a, [de] 
  inc de
  add a, c 
  ld [hl], a 
  ld a, c ;Store c 
  ld b, 0 
  ld c, UDRAW
  add hl, bc 
  ld c, a ;restore c  
  

  ld a, [de] 
  inc de 
  add a, c 
  ld [hl+], a 
  ld a, [de] 
  inc de 
  add a, c 
  ld [hl+], a 
  ld a, [de] 
  inc de  
  add a, c 
  ld [hl], a 
  ld a, c 
  ld b, 0 
  ld c, UDRAW
  add hl, bc 
  ld c, a 

  ld a, [de] 
  inc de 
  add a, c 
  ld [hl+], a 
  ld a, [de] 
  inc de 
  add a, c 
  ld [hl+], a 
  ld a, [de] 
  add a, c 
  ld [hl], a 

  ret 

ByteDecoder: 
  ; c: the byte to be decoded
  ; de: the address obtained by decoding c

  bit 2, c 
  jr z, .SkipColorReverse 
  ld b, 1 ; b: b=1 if selected 
  .SkipColorReverse:


  ld a, c 
  and %11110000
  srl a 
  srl a 
  srl a 
  srl a 
  ; This number tell us which block it is 
  inc a 
  ld hl, blockunits - BD

  push bc  
  ld b, 0 
  ld c, BD
.loop: 
  add hl, bc 
  dec a  
  jr nz, .loop 

  pop bc 

  ld a, c 
  and %00000011 
  add a, a 
  ld d, 0 
  ld e, a 
  add hl, de 
  ld e, [hl] ; Be careful with this order
  inc hl 
  ld d, [hl] 

  ret 


matrixToBGMap: 
  ; a: offSet 
  ; de: the BGOffSet to get 
  add a, a ;twice bigger since dw
  ld e, a 
  ld d, 0   
  ld hl, MatrixToSCRNOffSetTable 
  add hl, de
  ld a, [hl]   
  ld e, a ;Be careful 
  inc hl 
  ld a, [hl]
  ld d, a  
  ret  


computeHeight: 
  ld hl, affectedOffSetArray  
  ld a, [hl]
  push hl 
  call matrixToBGMap
  pop hl  
  ld b, d 
  ld c, e 
  ld a, c 
  and a, %11100000
  ld c, a 
.smallLoop: 
  ld a, [hl+] 
  or a  
  jr z, .myskip
  ld a, [hl+] 
  or a 
  jr z, .myskip 
  ld a, [hl+] 
  or a  
  jr z, .myskip 
  ld a, [hl+] 
  or a 
  jr z, .myskip  
  ld a, [hl+] 
  or a  
  jr z, .myskip 
  inc hl    
.myskip: 
  dec hl 
  dec hl 
  ld a, [hl]
  call matrixToBGMap ; bc and de 
  ld a, e 
  and a, %11100000
  ld e, a 
  
  ld h, b 
  ld l, c 
  call substraction ; get de - bc stored in hl
  srl l 
  srl l 
  srl l 
  srl l 
  srl l 
  bit 0, h 
  jr z, .skip 
  ld a, l 
  add a, %00001000
  ld l, a 
.skip: 
  ld b, l  
  inc b 
  inc b 
  inc b 
  ret  

  




setInitialAddressAndHeight: 
  call computeHeight
  ld hl, affectedOffSetArray  
  ld c, BLEFT ; max 
.compareFiveCoordinate: 
  ld a, [hl+] 
  or a
  jr z, .skip 
  push hl 
  call matrixToBGMap 
  pop hl  
  ld a, e 
  and a, %00011111 ; modulo 32 
  cp a, c 
  jr nc, .skip12
  ld c, a
.skip12: 
  ld a, [hl+] 
  or a
  jr z, .skip
  push hl 
  call matrixToBGMap 
  pop hl  
  ld a, e 
  and a, %00011111 ; modulo 32 
  cp a, c 
  jr nc, .skip22
  ld c, a
.skip22: 
  ld a, [hl+] 
  or a
  jr z, .skip
  push hl 
  call matrixToBGMap 
  pop hl  
  ld a, e 
  and a, %00011111 ; modulo 32 
  cp a, c 
  jr nc, .skip32
  ld c, a
.skip32: 
  ld a, [hl+] 
  or a
  jr z, .skip
  push hl 
  call matrixToBGMap 
  pop hl  
  ld a, e 
  and a, %00011111 ; modulo 32 
  cp a, c 
  jr nc, .skip42
  ld c, a
.skip42: 
  ld a, [hl+] 
  or a
  jr z, .skip
  push hl 
  call matrixToBGMap 
  pop hl  
  ld a, e 
  and a, %00011111 ; modulo 32 
  cp a, c 
  jr nc, .skip
  ld c, a
.skip: 
  

.setInitialAddress: 
  ld a, [affectedOffSetArray] 
  call matrixToBGMap 
  ld a, e 
  and a, %00011111
  ld h, a 
  ld a, e 
  sub a, h 
  add a, c 
  ld e, a 
  ld hl, _SCRN0 
  add hl, de 
  push hl 
  ld hl, shadowSCRN 
  add hl, de 
  ld d, h 
  ld e, l  
  pop hl 

  ld a, b 
  cp a, 12 
  jr c, .setZero
.setOne: 
  ld b, 1 
  ret  
.setZero 
  ld b, 0 
  ret  


matricesToShadowSCRN: 
  ;This function compare two matrices to write into shadowOAM 
  ;de: oldMatrix 
  ld a, 0 
  ld hl, affectedOffSetArray 
  ld [hl+], a 
  ld [hl+], a 
  ld [hl+], a 
  ld [hl+], a 
  ld [hl+], a 
  ld b, 0 
  ld c,MSIZE ; 42 elements in matrix 

  ld de, oldMatrix
  
.loop2: 
  ld h, d 
  ld l, e 
  ld a, [hl] ;The element in the old matrix 
  ld b, a 

  ld a, MSIZE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, b 

  push bc 
  ld b, [hl] ;The element in the new matrix
  cp a, b ;a is not affected?
  jr nz, .modify
.notModify: 
  ld a, 0 
  ld [recorded], a 
  jr .mySkip 
.modify: 
  call ModifyAndRecord
.mySkip: 
  pop bc 
  inc de 
  dec c 
  jr nz, .loop2
  ld a, 0 
  ld [recorded], a 
  
  ret 





ModifyAndRecord: 
  push de 
  ld a, b ;b: The number to be decoded 
  ld [de], a ;load into old matrix 
  

  ld a, MSIZE
  sub a, c 

  
  call matrixToBGMap 

  ld a, [recorded]  ; check if [recorded] = 0; 0 means the last coordinate in two matrices has no differences
  or a
  jr nz, .skip2     ; not zero then we do nothing 
  ld a, 1 
  ld [recorded], a
  ld hl, affectedOffSetArray 
.smallLoop: 
  ld a, [hl+] 
  or a  
  jr nz, .smallLoop 
  dec hl 
  ld a, MSIZE
  sub a, c 
  ld [hl], a ;Be careful 
.skip2: 
  
  ld hl, shadowSCRN 
  add hl, de ;The correct address of shadowSCRN 
  ld c, b ; c: The byte to be decoded 
  push hl 
  call ByteDecoder ;to get de: the unit address b: selected?
  pop hl 
  call UnitDraw 
  
  pop de 

  ret 
  



;---------------------------------------------------------------------
readKeys:
;---------------------------------------------------------------------
; Output:
; b : raw state:   pressing key triggers given action continuously
;                  as long as it is pressed
; c : rising edge: pressing key triggers given action only once,
;                  key must be released and pressed again
  ld    a,$20
  ldh   [rP1],a   
  ldh   a,[rP1]
  ldh   a,[rP1]
  cpl
  and   $0f         ; lower nibble has down, up, left, right
  swap	a           ; becomes high nibble
  ld	b,a
  ld    a,$10
  ldh   [rP1],a
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  ldh   a,[rP1]
  cpl
  and   $0f         ; lower nibble has start, select, B, A
  or    b
  ld    b,a

  ld    a,[previous]  ; load previous state
  xor   b	      ; result will be 0 if it's the same as current read
  and   b	      ; keep buttons that were pressed during this read only
  ld    [current],a   ; store result in "current" variable and c register
  ld    c,a
  ld    a,b           ; current state will be previous in next read
  ld    [previous],a

  ld    a,$30         ; reset rP1
  ldh   [rP1],a
  ret




displayMatrix: 
  call matricesToShadowSCRN 
  call ModifySCRNSelectivelyOld 
  ret 

matrixInitialize: 
  ; hl: the matrix to be initialized 
  ld hl, oldMatrix 
  ld b, MSIZE
  ld a, %01010000   

.loop3: 
  ld [hl+], a 
  dec b 
  jr nz, .loop3 
  ret   

InitializeLocalVariables: 
  ld hl, localVariableStart 
  ld bc, localVariableEnd - localVariableStart 
.loop 
  ld a, 0 
  ld [hl+], a 
  dec bc 
  ld a, b   
  or c  
  jr nz, .loop  
  ret 

InitializeGlobalVariables: 
  ld hl, globalVariableStart 
  ld bc, globalVariableEnd - globalVariableStart 
.loop 
  ld a, 0 
  ld [hl+], a 
  dec bc 
  ld a, b   
  or c  
  jr nz, .loop  
  ret 


InitializeObjects:
  ld hl, mouseCoord
  ld [hl], MOUSEY
  inc hl
  ld [hl], MOUSEX
  ld hl, mouseRow
  ld [hl], 0
  ld hl, mouseCol
  ld [hl], 0
  ret


mouse:
  call UpdateMouse
  call CopyMouseCoordToShadowOAM
  ret

CopyMouseCoordToShadowOAM:
  ld hl, mouseCoord
  ld de, shadowOAM
  ld a, [hl+]
  ld [de], a
  inc de
  ld a, [hl+]
  ld [de], a
  inc de
  ld a, 0
  ld [de], a
  inc de
  inc de
  ret

CopyShadowOAMtoOAM:
  ld hl, shadowOAM
  ld de, _OAMRAM
  ld a,[hl+]
  ld [de],a
  inc de
  ld a,[hl+]
  ld [de],a
  inc de
  ld a,[hl+]
  ld [de],a
  inc de
  ld a,[hl+]
  ld [de],a
  inc de
  ret

UpdateMouse:
  ld hl, mouseCoord
  ld a, [current]
  and a, %11110000
  cp a, %00010000
  call z, MouseChooseRight 
  cp a, %00100000
  call z, MouseChooseLeft 
  cp a, %10000000
  call z, MouseChooseDown
  cp a, %01000000
  call z, MouseChooseUp

  ret

MouseChooseRight:
  ld a, [mouseCol]
  cp a, %00000011
  ret z
  inc a
  ld [mouseCol], a
  ld hl, mouseCoord
  inc hl
  ld a, [hl]
  add a, CRIGHT
  ld [hl], a
  ret

MouseChooseLeft:
  ld a, [mouseCol]
  cp a, %00000000
  ret z
  dec a
  ld [mouseCol], a
  ld hl, mouseCoord
  inc hl
  ld a, [hl]
  sub a, CRIGHT
  ld [hl], a
  ret

MouseChooseDown:
  ld a, [mouseRow]
  cp a, %00000001
  ret z
  inc a
  ld [mouseRow], a
  ld hl, mouseCoord
  ld a, [hl]
  add a, CRIGHT
  ld [hl], a
  ret

MouseChooseUp:
  ld a, [mouseRow]
  cp a, %00000000
  ret z
  dec a
  ld [mouseRow], a
  ld hl, mouseCoord
  ld a, [hl]
  sub a, CRIGHT
  ld [hl], a
  ret

ModifySCRNSelectively:
  ; b = 0 shorter 
  ; b = 1 higher 
  ld a, b   
  or a   
  jp z, shorterFunction
  dec b 
  jp higherFunction   
  

ModifySCRNSelectivelyOld: 
; This is logically right? But I can't see
;ld hl, recorded + 1 
;ld b, [hl] ; I don't know why BC have inverse bytes 
;inc hl  
;ld c, [hl] ;bc now is the offset

  ld a, [recorded + 1] 

  ld hl, _SCRN0 + MCS
  ld de, shadowSCRN + MCS

  ld b, TRIGHT

.smallLoopUpper2
  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 
  
  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 


  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 

  dec b 
  jr nz, .smallLoopUpper2

  ret
  


higherFunction: 

  ; bc and de is set 

  ;24*9
  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, CYCLE
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, CYCLE
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ret   




shorterFunction: 

  ; bc and de is set 


  ;24*12=288
  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 



  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 



  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL 
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ;56cycles
  ld a, SMALL
  add a, l 
  ld l, a 
  adc a, h 
  sub a, l 
  ld h, a
  ld a, SMALL
  add a, e 
  ld e, a 
  adc a, d 
  sub a, e 
  ld d, a 


  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 

  ld a, [de] 
  ld [hl+], a 
  inc de 


  ret  

