.include "def.inc"
.globl      InitObjectPool
.globl		AllocateObjBlock
.globl		FreeObjBlock 
.globl		ZeroObjZbuf
.globl		CallObjRoutine

InitObjectPool:          |1f24               
                                        
        lea     (OBJ_LIST_HEAD).l, a0
        move.l  #EmptyRoutine, Object(a0) 
        move.l  #0x100300, d0
        move.w  d0, Object.PNext(a0)
        move.w  #0xFFFF, Object.PPrev(a0)
        move.l  #EmptyRoutine, 0x200(a0) 

        move.w  #0xFFFF, Object.PNext+0x200(a0)
        move.l  #OBJ_LIST_HEAD, d0
        move.w  d0, Object.PPrev+0x200(a0)
        move.w  #0xFFFF, Object.Level+0x200(a0)
        lea     A5Seg.SpritePoolBaseTable(a5), a0
        move.l  #0x107F00, d0
        move.w  #0x3D, d1               | loop time 3e

_obj_dbfLoop:                               | CODE XREF: InitObjectPool+4Ej
        move.w  d0, (a0)+
        subi.w  #0x200, d0
        dbf     d1, _obj_dbfLoop
        move.w  #0x7A, A5Seg.ObjPoolStackIndex(a5)
        |andi.b  #0x80, A5Seg.debugDipFlagCopy(a5) | bit0: 1, debug obj exist
                                        | bit1: 1, show hit box
                                        | bit4: 1, need clear DbgPlayerStatusFlags display
        |clr.b   A5Seg.noUse(a5)
        rts
| End of function InitObjectPool

EmptyRoutine:
		rts

AllocateObjBlock:                       |1f82
        move.w  A5Seg.ObjPoolStackIndex(a5), d7
        bmi.w   _AllocateObjBlock_overflow               | if (curIndex > 0x7F)
                                        |     goto ...overflow
        subq.w  #2, A5Seg.ObjPoolStackIndex(a5) | curIndex -= 2
                                        | 注意此时 d7 没有变
        lea     A5Seg.SpritePoolBaseTable(a5), a1 | 10a700
        movea.w (a1,d7.w), a1
        adda.l  #0x100000, a1
        move.l  a0, Object(a1)
        move.w  d0, Object.Level(a1)    | 数值越小, 处理程序越先被执行 (优先级越高).
                                        | 也用于判断是否冻结画面
        lea     -0x7F00(a5), a0         | 100100 链表头
        move.l  a0, d7

_AllocateObjBlock_findPosition:                          | CODE XREF: AllocateObjBlock+30j
        move.w  Object.PNext(a0), d7
        movea.l d7, a0                  | a0 = 100000 + *(a0+4)
        cmp.w   Object.Level(a0), d0    | 数值越小, 处理程序越先被执行 (优先级越高).
                                        | 也用于判断是否冻结画面
        bcc.s   _AllocateObjBlock_findPosition           | if(8(a0)<=d0) goto
        move.w  a0, Object.PNext(a1)    | 找到了一个 level 足够大的块
                                        | 把原来的块按照level顺序插进链表
        move.w  Object.PPrev(a0), Object.PPrev(a1)
        move.w  Object.PPrev(a0), d7
        move.w  a1, Object.PPrev(a0)
        movea.l d7, a0
        move.w  a1, Object.PNext(a0)
        lea     Object.TagString(a1), a0
        move.w  #0x1E, d0
        moveq   #0, d7
_AllocateObjBlock_zeroLoop:                              
        move.l  d7, (a0)+
        move.l  d7, (a0)+
        move.l  d7, (a0)+
        move.l  d7, (a0)+
        dbf     d0, _AllocateObjBlock_zeroLoop           | 清零 0x1f0
        rts
| ---------------------------------------------------------------------------

_AllocateObjBlock_overflow:                              
        lea     (TASK_OVER).l, a0       | task over
        jsr     SetFixlayText           | params:
                                        |     a0: ptr to fixlay output struct

_AllocateObjBlock_deathLoop:                           
        bra.w   _AllocateObjBlock_deathLoop
| End of function AllocateObjBlock


| params:
|     a4: Obj

FreeObjBlock:                          
                                       
        lea     A5Seg.SpritePoolBaseTable(a5), a0
        addq.w  #2, A5Seg.ObjPoolStackIndex(a5)
        moveq   #0, d0
        move.w  A5Seg.ObjPoolStackIndex(a5), d0
        move.w  a4, (a0,d0.w)           | 释放当前的200_Block
        move.l  #0x100000, d0
        move.w  Object.PPrev(a4), d0    | 将此Block从链表中断开
        movea.l d0, a0
        move.w  Object.PNext(a4), Object.PNext(a0)
        move.w  Object.PNext(a4), d0
        movea.l d0, a0
        move.w  Object.PPrev(a4), Object.PPrev(a0)
        move.w  #0xFFFF, Object.PPrev(a4) | 前一个节点为空, 表示不处在运行链中
        rts
| End of function FreeObjBlock


ZeroObjZbuf:                            | CODE XREF: GameLogicMainLoopEntry+F2p
        lea     A5Seg.ObjZBuf(a5), a0   | size: 0x600
        moveq   #0, d0
        moveq   #0x2F, d1               | $30 * $20

_ZeroObjZbuf_dbfLoop:                               | CODE XREF: ZeroObjZbuf+18j
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        move.l  d0, (a0)+
        dbf     d1, _ZeroObjZbuf_dbfLoop
        move.l  #0x108700, A5Seg.pGhostBuf(a5) | 影跳的影子等
                                        | 指向可用的临时缓冲区用于构造obj头, 每块0x40, 总大小0x200
        move.l  #0xFFFE, A5Seg.FirstObjIndexInZBuf(a5) | 指示第一个带非0的Obj在Zbuf中的偏移, -2 表示Zbuf为空
        clr.w   A5Seg.NumInObjZBuf(a5)
        rts
| End of function ZeroObjZbuf


CallObjRoutine:                         
        lea     A5Seg.MainNextRoutine(a5), a4 | a4 = 108500
        movea.l (a4), a0
        jsr     (a0)                    
        |bsr.w   FlashOneMore
        move.l  #OBJ_LIST_HEAD, d7
|        btst    #2, A5Seg.RoleObjMaskFlags(a5) | bit0: 1, lock p1
|                                        | bit1: 1, lock p2
|                                        | bit2: 1, freeze mode, 必杀画面
|        beq.s   _CallObjRoutine_normalLoop
|
|_CallObjRoutine_freezeLoop:                            | CODE XREF: CallObjRoutine+32j
|        movea.l d7, a4                  | set a4 = next obj
|        move.w  Object.Level(a4), d7    | 用于判断是否冻结画面
|        cmp.w   A5Seg.unfreezeLevelNum(a5), d7 | 不冻结的level编号
|        bne.w   _CallObjRoutine_unfreezeObj
|        movea.l Object(a4), a0
|        jsr     (a0)                    | 冻结的时候仍然会执行obj处理例程
|
|_CallObjRoutine_goNextLoop:                            | CODE XREF: CallObjRoutine+3Ej
|                                        | CallObjRoutine+52j
|        move.l  a4, d7
|        move.w  Object.PNext(a4), d7
|        bpl.s   _CallObjRoutine_freezeLoop
|        bra.w   loc_9DF8
|| ---------------------------------------------------------------------------
|
|_CallObjRoutine_unfreezeObj:                           | CODE XREF: CallObjRoutine+24j
|        btst    #5, Object.ExGraphFlags(a4) | bit0: 1, need to update SCB1
|                                        | bit1: 1, do not use extra graph
|                                        | bit2: 1, 使用缓移层背景
|                                        | bit3: ?
|                                        | bit4: 1, use own Shrinking, do not set InScreenX,Y 倒影用
|                                        | bit5: 1, visible during freeze
|                                        | bit7: 1, use sub SCB3 buf
|        beq.s   _CallObjRoutine_goNextLoop
|        move.b  #1, Object.SpanTimeEx(a4)
|        jsr     (GetNextMov).l          | ret:
|                                        |     d0: 0, done;
|                                        |        -1, new graph info loaded
|        jsr     (InsertIntoObjZBuf).l   | params:
|                                        |     a4: obj
|                                        | ret:
|                                        |     d6: 0, done; -1: fail
|        bra.s   _CallObjRoutine_goNextLoop
|| ---------------------------------------------------------------------------

_CallObjRoutine_normalLoop:            
        movea.l d7, a4
        movea.l Object(a4), a0
        jsr     (a0)
        move.l  a4, d7
        move.w  Object.PNext(a4), d7
        bpl.s   _CallObjRoutine_normalLoop             | 循环执行每个obj的处理例程

		lea     (0x10B0B2).l, a4      | BackGroundObjLayer0
        move.b  #8, A5Seg.PendingNumOfBackgroundLayerToUpdate(a5)

_CallObjRoutine_layerLoop:                             | CODE XREF: CallObjRoutine+A2j
        tst.b   ScreenObj.Flag(a4)      | bit1: 1, do not show this layer
                                        | bit1: 1, do not scroll X
                                        | bit2: 1, do not scrool Y
                                        | bit5: 1, do not ... ?
                                        | bit6: 1, sticky
                                        | bit7: 0, do not use layer proc
        bpl.s   _CallObjRoutine_nextLayer                | 游戏中实际只是用3层背景
        movea.l ScreenObj(a4), a0       | 主例程
        jsr     (a0)

_CallObjRoutine_nextLayer:                               | CODE XREF: CallObjRoutine+94j
        lea     0x100(a4), a4
        subq.b  #1, A5Seg.PendingNumOfBackgroundLayerToUpdate(a5)
        bne.s   _CallObjRoutine_layerLoop
        rts
| End of function CallObjRoutine

TASK_OVER:
		.word 0x7191                  
        .byte  0xF
        .ascii "TASK OVER !!"
        .byte 0xFF

