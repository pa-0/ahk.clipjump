﻿;@Plugin-Name Ignored Window Manager
;@Plugin-Description Manages the windows that will be ignored by Clipjump Clipboard monitoring and paste mode.
;@Plugin-Author fump2000
;@Plugin-Version 0.1
;@Plugin-Tags system

global cj := new Clipjump()
global PROGNAME := cj.PROGNAME
global TXT := {}

TXT.IGN_delete := cj["TXT.IGN_delete"] , TXT.IGN_add := cj["TXT.IGN_add"]
TXT.IGN__name := cj["TXT.IGN__name"] , TXT.IGN_RestartMsg := cj["TXT.IGN_RestartMsg"]
TXT.IGN_tip := cj["TXT.IGN_tip"]

ClassManager()
#Include %A_ScriptDir%\..\publicAPI.ahk

;============================================================================
; Class-Manager for ClipJump
;============================================================================
ClassManager() {

   global ClipClass
   Gui, ClipClass:New
   Gui, ClipClass:Color, FFFFFF
   Gui, ClipClass:-MaximizeBox
   Gui, ClipClass:Add, ListView, x0 y0 w320 h260 +BackgroundD9E7FB NoSortHdr +AltSubmit -Multi vClipClass gClipClass HWNDh_LVClass, Classes
   Gui, ClipClass:Add, Button, x0 y260 w320 h30 gClassDelete, % TXT.IGN_delete
   Gui, ClipClass:Add, Button, x0 y290 w320 h30 gAddClass, % TXT.IGN_add
   Gui, ClipClass:Show, w320 h325, % PROGNAME " " TXT.IGN__name
   LV_Colors.OnMessage()
   LV_Colors.Attach(h_LVClass, False)
   GoSub FillClassList
   Return

ClipClass:
   if A_GuiEvent = Normal
   {
      LV_GetText(ClipClassSelection, A_EventInfo)
      ClassRowNumber := A_EventInfo
      gosub LVClassColor
      LV_Colors.Row(h_LVClass, A_EventInfo, 0x86e855, 0x000000) ; Change color to green  
   }
   Return

LVClassColor:
   Gui, ListView, %h_LVClass%
   LVName:="ClipClass"
   Loop % LV_GetCount()
   	{
   		GuiControl, -ReDraw, %LVName%
   		LV_Colors.Row(h_LVClass, A_Index, 0xD9E7FB, 0x000000) ; Change color to 0xD9E7FB
   		GuiControl, +ReDraw, %LVName%
   	}
   Return

FillClassList:
   Gui, ClipClass:Default
   GuiControl, -Redraw, ClipClass
   LV_Delete()
   LV_ModifyCol()
   LV_ModifyCol(1, 315)

   IniRead,OutVar,%A_WorkingDir%\settings.ini,Advanced,ignoreWindows
   Loop, parse, OutVar, |
   	{
   		If A_LoopField =
   		break
   		
   		LV_Add(Classen,A_LoopField)
   	}
   GuiControl, +Redraw, ClipClass
   Return

ClassDelete:
   Gui, ClipClass:Default
   LV_Delete( LV_GetNext(0) )
   GoSub LVClassColor
   GoSub SaveClasses
   ClassChange:=1
   Return

ClipClassGuiClose:
   If ClassChange
   {
      MsgBox, 67, % PROGNAME, % TXT.IGN_RestartMsg
      IfMsgBox, Yes
         cj.runLabel("reload")
      IfMsgBox, No
         Gui, ClipClass:Destroy
      IfMsgBox, Cancel
         return      ; dont Exitapp
   }
   Else  Gui, ClipClass:Destroy
   ExitApp
   Return

AddClass:
   GoSub LVClassColor
   ClipClassSelection:=""
   classtool_cl := classget_Tool()
   WinActivate, % PROGNAME " " TXT.IGN__name
   If (classtool_cl="")
   	Return
   else
   	{
   		LV_Add(Classen,classtool_cl)
   		GoSub SaveClasses
   		GoSub LVClassColor
   		ClassChange:=1
   	}
   Return

SaveClasses:
   ClipClasses:=""
   Loop % LV_GetCount()
   	{
   		LV_GetText(ClassHelper, A_Index)
   		ClipClasses:=ClipClasses . ClassHelper "|"
   	}
   IniWrite,%ClipClasses%,%A_WorkingDir%\settings.ini,Advanced,ignoreWindows
   Return

}


classget_Tool(){

	global classtool_cl
	classTool_active := 1

	setTimer, classget, 200
	Hotkey, Esc,  classTool_end, On
	Hotkey, Space, classTool_copy, On

	while classTool_active
		sleep 20

	setTimer, classget, Off
	btt(,,, 6)
	Hotkey, Esc, classTool_end, Off
	Hotkey, Space, classTool_copy, Off
	return classtool_cl

classget:
	WinGetClass, classtool_cl, A
	btt(classtool_cl "`n`n" TXT.IGN_tip,,, 6)
	return

classTool_copy:
	classTool_active := 0
	return

classTool_end:
	classtool_cl:=""
	classTool_active := 0
	return

}
;============================================================================


; ======================================================================================================================
; Namespace:      LV_Colors
; AHK version:    AHK 1.1.09.02
; Function:       Helper object and functions for ListView row and cell coloring
; Language:       English
; Tested on:      Win XPSP3, Win VistaSP2 (U32) / Win 7 (U64)
; Version:        0.1.00.00/2012-10-27/just me
;                 0.2.00.00/2013-01-12/just me - bugfixes and minor changes
;                 0.3.00.00/2013-06-15/just me - added "Critical, 100" to avoid drawing issues
; ======================================================================================================================
; CLASS LV_Colors
;
; The class provides seven public methods to register / unregister coloring for ListView controls, to set individual
; colors for rows and/or cells, to prevent/allow sorting and rezising dynamically, and to register / unregister the
; included message handler function for WM_NOTIFY -> NM_CUSTOMDRAW messages.
;
; If you want to use the included message handler you must call LV_Colors.OnMessage() once.
; Otherwise you should integrate the code within LV_Colors_WM_NOTIFY into your own notification handler.
; Without notification handling coloring won't work.
; ======================================================================================================================
Class LV_Colors {
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; PRIVATE PROPERTIES ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   Static MessageHandler := "LV_Colors_WM_NOTIFY"
   Static WM_NOTIFY := 0x4E
   Static SubclassProc := RegisterCallback("LV_Colors_SubclassProc")
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; META FUNCTIONS ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   __New(P*) {
      Return False   ; There is no reason to instantiate this class!
   }
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; PRIVATE METHODS +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   On_NM_CUSTOMDRAW(H, L) {
      Static CDDS_PREPAINT          := 0x00000001
      Static CDDS_ITEMPREPAINT      := 0x00010001
      Static CDDS_SUBITEMPREPAINT   := 0x00030001
      Static CDRF_DODEFAULT         := 0x00000000
      Static CDRF_NEWFONT           := 0x00000002
      Static CDRF_NOTIFYITEMDRAW    := 0x00000020
      Static CDRF_NOTIFYSUBITEMDRAW := 0x00000020
      Static CLRDEFAULT             := 0xFF000000
      ; Size off NMHDR structure
      Static NMHDRSize := (2 * A_PtrSize) + 4 + (A_PtrSize - 4)
      ; Offset of dwItemSpec (NMCUSTOMDRAW)
      Static ItemSpecP := NMHDRSize + (5 * 4) + A_PtrSize + (A_PtrSize - 4)
      ; Size of NMCUSTOMDRAW structure
      Static NCDSize  := NMHDRSize + (6 * 4) + (3 * A_PtrSize) + (2 * (A_PtrSize - 4))
      ; Offset of clrText (NMLVCUSTOMDRAW)
      Static ClrTxP   :=  NCDSize
      ; Offset of clrTextBk (NMLVCUSTOMDRAW)
      Static ClrTxBkP := ClrTxP + 4
      ; Offset of iSubItem (NMLVCUSTOMDRAW)
      Static SubItemP := ClrTxBkP + 4
      ; Offset of clrFace (NMLVCUSTOMDRAW)
      Static ClrBkP   := SubItemP + 8
      DrawStage := NumGet(L + NMHDRSize, 0, "UInt")
      , Row := NumGet(L + ItemSpecP, 0, "UPtr") + 1
      , Col := NumGet(L + SubItemP, 0, "Int") + 1
      ; SubItemPrepaint ------------------------------------------------------------------------------------------------
      If (DrawStage = CDDS_SUBITEMPREPAINT) {
         NumPut(This[H].CurTX, L + ClrTxP, 0, "UInt"), NumPut(This[H].CurTB, L + ClrTxBkP, 0, "UInt")
         , NumPut(This[H].CurBK, L + ClrBkP, 0, "UInt")
         ClrTx := This[H].Cells[Row][Col].T, ClrBk := This[H].Cells[Row][Col].B
         If (ClrTx <> "")
            NumPut(ClrTX, L + ClrTxP, 0, "UInt")
         If (ClrBk <> "")
            NumPut(ClrBk, L + ClrTxBkP, 0, "UInt"), NumPut(ClrBk, L + ClrBkP, 0, "UInt")
         If (Col > This[H].Cells[Row].MaxIndex()) && !This[H].HasKey(Row)
            Return CDRF_DODEFAULT
         Return CDRF_NOTIFYSUBITEMDRAW
      }
      ; ItemPrepaint ---------------------------------------------------------------------------------------------------
      If (DrawStage = CDDS_ITEMPREPAINT) {
         This[H].CurTX := This[H].TX, This[H].CurTB := This[H].TB, This[H].CurBK := This[H].BK
         ClrTx := ClrBk := ""
         If This[H].Rows.HasKey(Row)
            ClrTx := This[H].Rows[Row].T, ClrBk := This[H].Rows[Row].B
         If (ClrTx <> "")
            NumPut(ClrTx, L + ClrTxP, 0, "UInt"), This[H].CurTX := ClrTx
         If (ClrBk <> "")
            NumPut(ClrBk, L + ClrTxBkP, 0, "UInt") , NumPut(ClrBk, L + ClrBkP, 0, "UInt")
            , This[H].CurTB := ClrBk, This[H].CurBk := ClrBk
         If This[H].Cells.HasKey(Row)
            Return CDRF_NOTIFYSUBITEMDRAW
         Return CDRF_DODEFAULT
      }
      ; Prepaint -------------------------------------------------------------------------------------------------------
      If (DrawStage = CDDS_PREPAINT) {
         Return CDRF_NOTIFYITEMDRAW
      }
      ; Others ---------------------------------------------------------------------------------------------------------
      Return CDRF_DODEFAULT
   }
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; PUBLIC METHODS ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; ===================================================================================================================
   ; Attach()        Register ListView control for coloring
   ; Parameters:     HWND        -  ListView's HWND.
   ;                 Optional ------------------------------------------------------------------------------------------
   ;                 NoSort      -  Prevent sorting by click on a header item.
   ;                                Values:  True / False
   ;                                Default: True
   ;                 NoSizing    -  Prevent resizing of columns.
   ;                                Values:  True / False
   ;                                Default: True
   ; Return Values:  True on success, otherwise false.
   ; ===================================================================================================================
   Attach(HWND, NoSort = True, NoSizing = True) {
      Static LVM_GETBKCOLOR     := 0x1000
      Static LVM_GETHEADER      := 0x101F
      Static LVM_GETTEXTBKCOLOR := 0x1025
      Static LVM_GETTEXTCOLOR   := 0x1023
      Static LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1036
      Static LVS_EX_DOUBLEBUFFER := 0x00010000
      If !DllCall("User32.dll\IsWindow", "Ptr", HWND, "UInt")
         Return False
      If This.HasKey(HWND)
         Return False
      ; Set LVS_EX_DOUBLEBUFFER style to avoid drawing issues, if it isn't set as yet.
      SendMessage, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER, , ahk_id %HWND%
      If (ErrorLevel = "FAIL")
         Return False
      ; Get the default colors
      SendMessage, LVM_GETBKCOLOR, 0, 0, , ahk_id %HWND%
      BkClr := ErrorLevel
      SendMessage, LVM_GETTEXTBKCOLOR, 0, 0, , ahk_id %HWND%
      TBClr := ErrorLevel
      SendMessage, LVM_GETTEXTCOLOR, 0, 0, , ahk_id %HWND%
      TxClr := ErrorLevel
      ; Get the header control
      SendMessage, LVM_GETHEADER, 0, 0, , ahk_id %HWND%
      Header := ErrorLevel
      ; Store the values in a new object
      This[HWND] := {BK: BkClr, TB: TBClr, TX: TxClr, Header: Header}
      If (NoSort)
         This.NoSort(HWND)
      If (NoSizing)
         This.NoSizing(HWND)
      Return True
   }
   ; ===================================================================================================================
   ; Detach()        Unregister ListView control
   ; Parameters:     HWND        -  ListView's HWND
   ; Return Value:   Always True
   ; ===================================================================================================================
   Detach(HWND) {
      ; Remove the subclass, if any
      If (This[HWND].SC)
         DllCall("Comctl32.dll\RemoveWindowSubclass", "Ptr", HWND, "Ptr", This.SubclassProc, "Ptr", HWND)
      This.Remove(HWND, "")
      WinSet, Redraw, , ahk_id %HWND%
      Return True
   }
   ; ===================================================================================================================
   ; Row()           Set background and/or text color for the specified row
   ; Parameters:     HWND        -  ListView's HWND
   ;                 Row         -  Row number
   ;                 Optional ------------------------------------------------------------------------------------------
   ;                 BkColor     -  Background color as RGB color integer (e.g. 0xFF0000 = red)
   ;                                Default: Empty -> default background color
   ;                 TxColor     -  Text color as RGB color integer (e.g. 0xFF0000 = red)
   ;                                Default: Empty -> default text color
   ; Return Value:   True on success, otherwise false.
   ; ===================================================================================================================
   Row(HWND, Row, BkColor = "", TxColor = "") {
      If !This.HasKey(HWND)
         Return False
      If (BkColor = "") && (TxColor = "") {
         This[HWND].Rows.Remove(Row, "")
         Return True
      }
      BkBGR := TxBGR := ""
      If BkColor Is Integer
         BkBGR := ((BkColor & 0xFF0000) >> 16) | (BkColor & 0x00FF00) | ((BkColor & 0x0000FF) << 16)
      If TxColor Is Integer
         TxBGR := ((TxColor & 0xFF0000) >> 16) | (TxColor & 0x00FF00) | ((TxColor & 0x0000FF) << 16)
      If (BkBGR = "") && (TxBGR = "")
         Return False
      If !This[HWND].HasKey("Rows")
         This[HWND].Rows := {}
      If !This[HWND].Rows.HasKey(Row)
         This[HWND].Rows[Row] := {}
      If (BkBGR <> "")
         This[HWND].Rows[Row].Insert("B", BkBGR)
      If (TxBGR <> "")
         This[HWND].Rows[Row].Insert("T", TxBGR)
      Return True
   }
   ; ===================================================================================================================
   ; Cell()          Set background and/or text color for the specified cell
   ; Parameters:     HWND        -  ListView's HWND
   ;                 Row         -  Row number
   ;                 Col         -  Column number
   ;                 Optional ------------------------------------------------------------------------------------------
   ;                 BkColor     -  Background color as RGB color integer (e.g. 0xFF0000 = red)
   ;                                Default: Empty -> default background color
   ;                 TxColor     -  Text color as RGB color integer (e.g. 0xFF0000 = red)
   ;                                Default: Empty -> default text color
   ; Return Value:   True on success, otherwise false.
   ; ===================================================================================================================
   Cell(HWND, Row, Col, BkColor = "", TxColor = "") {
      If !This.HasKey(HWND)
         Return False
      If (BkColor = "") && (TxColor = "") {
         This[HWND].Cells.Remove(Row, "")
         Return True
      }
      BkBGR := TxBGR := ""
      If BkColor Is Integer
         BkBGR := ((BkColor & 0xFF0000) >> 16) | (BkColor & 0x00FF00) | ((BkColor & 0x0000FF) << 16)
      If TxColor Is Integer
         TxBGR := ((TxColor & 0xFF0000) >> 16) | (TxColor & 0x00FF00) | ((TxColor & 0x0000FF) << 16)
      If (BkBGR = "") && (TxBGR = "")
         Return False
      If !This[HWND].HasKey("Cells")
         This[HWND].Cells := {}
      If !This[HWND].Cells.HasKey(Row)
         This[HWND].Cells[Row] := {}
      This[HWND].Cells[Row, Col] := {}
      If (BkBGR <> "")
         This[HWND].Cells[Row, Col].Insert("B", BkBGR)
      If (TxBGR <> "")
         This[HWND].Cells[Row, Col].Insert("T", TxBGR)
      Return True
   }
   ; ===================================================================================================================
   ; NoSort()        Prevent / allow sorting by click on a header item dynamically.
   ; Parameters:     HWND        -  ListView's HWND
   ;                 Optional ------------------------------------------------------------------------------------------
   ;                 DoIt        -  True / False
   ;                                Default: True
   ; Return Value:   True on success, otherwise false.
   ; ===================================================================================================================
   NoSort(HWND, DoIt = True) {
      Static HDM_GETITEMCOUNT := 0x1200
      If !This.HasKey(HWND)
         Return False
      If (DoIt)
         This[HWND].NS := True
      Else
         This[HWND].Remove("NS")
      Return True
   }
   ; ===================================================================================================================
   ; NoSizing()      Prevent / allow resizing of columns dynamically.
   ; Parameters:     HWND        -  ListView's HWND
   ;                 Optional ------------------------------------------------------------------------------------------
   ;                 DoIt        -  True / False
   ;                                Default: True
   ; Return Value:   True on success, otherwise false.
   ; ===================================================================================================================
   NoSizing(HWND, DoIt = True) {
      Static OSVersion := DllCall("Kernel32.dll\GetVersion", "UChar")
      Static HDS_NOSIZING := 0x0800
      If !This.HasKey(HWND)
         Return False
      HHEADER := This[HWND].Header
      If (DoIt) {
         If (OSVersion < 6) {
            If !(This[HWND].SC) {
               DllCall("Comctl32.dll\SetWindowSubclass", "Ptr", HWND, "Ptr", This.SubclassProc, "Ptr", HWND, "Ptr", 0)
               This[HWND].SC := True
            } Else {
               Return True
            }
         } Else {
            Control, Style, +%HDS_NOSIZING%, , ahk_id %HHEADER%
         }
      } Else {
         If (OSVersion < 6) {
            If (This[HWND].SC) {
               DllCall("Comctl32.dll\RemoveWindowSubclass", "Ptr", HWND, "Ptr", This.SubclassProc, "Ptr", HWND)
               This[HWND].Remove("SC")
            } Else {
               Return True
            }
         } Else {
            Control, Style, -%HDS_NOSIZING%, , ahk_id %HHEADER%
         }
      }
      Return True
   }
   ; ===================================================================================================================
   ; OnMessage()     Register / unregister LV_Colors message handler for WM_NOTIFY -> NM_CUSTOMDRAW messages
   ; Parameters:     DoIt        -  True / False
   ;                                Default: True
   ; Return Value:   Always True
   ; ===================================================================================================================
   OnMessage(DoIt = True) {
      If (DoIt)
         OnMessage(This.WM_NOTIFY, This.MessageHandler)
      Else If (This.MessageHandler = OnMessage(This.WM_NOTIFY))
         OnMessage(This.WM_NOTIFY, "")
      Return True
   }
}
; ======================================================================================================================
; PRIVATE FUNCTION LV_Colors_WM_NOTIFY() - message handler for WM_NOTIFY -> NM_CUSTOMDRAW notifications
; ======================================================================================================================
LV_Colors_WM_NOTIFY(W, L) {
   Static NM_CUSTOMDRAW := -12
   Static LVN_COLUMNCLICK := -108
   Critical, 100
   If LV_Colors.HasKey(H := NumGet(L + 0, 0, "UPtr")) {
      M := NumGet(L + (A_PtrSize * 2), 0, "Int")
      ; NM_CUSTOMDRAW --------------------------------------------------------------------------------------------------
      If (M = NM_CUSTOMDRAW)
         Return LV_Colors.On_NM_CUSTOMDRAW(H, L)
      ; LVN_COLUMNCLICK ------------------------------------------------------------------------------------------------
      If (LV_Colors[H].NS && (M = LVN_COLUMNCLICK))
         Return 0
   }
}
; ======================================================================================================================
; PRIVATE FUNCTION LV_Colors_SubclassProc() - subclass for WM_NOTIFY -> HDN_BEGINTRACK notifications (Win XP)
; ======================================================================================================================
LV_Colors_SubclassProc(H, M, W, L, S, R) {
   Static HDN_BEGINTRACKA := -306
   Static HDN_BEGINTRACKW := -326
   Static WM_NOTIFY := 0x4E
   Critical, 100
   If (M = WM_NOTIFY) {
      ; HDN_BEGINTRACK -------------------------------------------------------------------------------------------------
      C := NumGet(L + (A_PtrSize * 2), 0, "Int")
      If (C = HDN_BEGINTRACKA) || (C = HDN_BEGINTRACKW) {
         Return True
      }
   }
   Return DllCall("Comctl32.dll\DefSubclassProc", "Ptr", H, "UInt", M, "Ptr", W, "Ptr", L, "UInt")
}
; ======================================================================================================================

#Include %A_ScriptDir%\..\lib\btt.ahk