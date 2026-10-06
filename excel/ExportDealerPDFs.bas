Attribute VB_Name = "Module1"
Sub ExportDealerPDFs()
    ' Saves one PDF scorecard per dealer into the excel/pdf folder.

    Dim card As Worksheet, dataSheet As Worksheet
    Dim folder As String, sep As String
    Dim r As Long, lastRow As Long

    Set card = Worksheets("Scorecard")
    Set dataSheet = Worksheets("Data")
    sep = Application.PathSeparator             ' "/" on Mac, "\" on Windows
    folder = ThisWorkbook.Path & sep & "pdf" & sep

    #If Mac Then
        GrantAccessToMultipleFiles Array(folder)   ' Mac asks permission once
    #End If

    ' Find the last dealer row in column A
    lastRow = dataSheet.Cells(dataSheet.Rows.Count, "A").End(xlUp).Row

    ' Loop: row 2 is the first dealer (row 1 is the header)
    For r = 2 To lastRow
        card.Range("B3").Value = dataSheet.Cells(r, 1).Value
        card.ExportAsFixedFormat Type:=xlTypePDF, _
            FileName:=folder & dataSheet.Cells(r, 1).Value & ".pdf"
    Next r

    MsgBox (lastRow - 1) & " PDFs saved in " & folder
End Sub

