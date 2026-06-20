program LottoCombinations;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Diagnostics;

const
  POOL_SIZE = 34;        // numbers 1..34
  PICK_COUNT = 7;        // choose 7
  OUTPUT_FILE = 'lotto_combinations.csv';
  FLUSH_THRESHOLD = 1 shl 20; // flush buffer when it grows past ~1 MB of text

{ TCombinationGenerator walks all PICK_COUNT-element subsets of 1..POOL_SIZE
  in strictly increasing (lexicographic) order using an "odometer" technique:
  each wheel only rolls over once it has hit the maximum value its position
  allows, then the next wheel to the left ticks forward and every wheel to
  the right resets to the smallest legal value. Because every combination is
  forced into strictly increasing order, no duplicate and no permutation of
  the same set can ever be produced - order-independence falls out for free. }
type
  TCombinationGenerator = class
  public
    FIndices: array[0..PICK_COUNT - 1] of Integer; // current combination, 1-based numbers
    FFinished: Boolean;
    FIsFirst: Boolean;
    constructor Create;
    function Next: Boolean; // advances to the next combination; False when exhausted
  end;

constructor TCombinationGenerator.Create;
var
  i: Integer;
begin
  inherited Create;
  for i := 0 to PICK_COUNT - 1 do
    FIndices[i] := i + 1; // smallest valid combination: 1,2,3,4,5,6,7
  FFinished := False;
  FIsFirst := True;
end;

function TCombinationGenerator.Next: Boolean;
var
  i, j: Integer;
begin
  if FFinished then
    Exit(False);

  if FIsFirst then
  begin
    // First call just returns the initial 1,2,3,...,PICK_COUNT combination.
    FIsFirst := False;
    Exit(True);
  end;

  // Find the rightmost wheel that hasn't hit its maximum allowed value yet.
  // Wheel at position i (0-based) maxes out at POOL_SIZE - (PICK_COUNT - 1 - i).
  i := PICK_COUNT - 1;
  while (i >= 0) and (FIndices[i] = POOL_SIZE - (PICK_COUNT - 1 - i)) do
    Dec(i);

  if i < 0 then
  begin
    // Every wheel was maxed out - we already emitted the very last
    // combination (POOL_SIZE-PICK_COUNT+1 .. POOL_SIZE) on the previous call.
    FFinished := True;
    Exit(False);
  end;

  Inc(FIndices[i]);
  for j := i + 1 to PICK_COUNT - 1 do
    FIndices[j] := FIndices[j - 1] + 1;

  Result := True;
end;

procedure GenerateAllCombinations;
var
  Generator: TCombinationGenerator;
  OutputStream: TFileStream;
  Buffer: TStringBuilder;
  RowText: string;
  k: Integer;
  Total: Int64;
  Stopwatch: TStopwatch;
  Encoding: TEncoding;
  Bytes: TBytes;
begin
  WriteLn('Generating all C(', POOL_SIZE, ',', PICK_COUNT, ') combinations...');

  Generator := TCombinationGenerator.Create;
  Buffer := TStringBuilder.Create;
  OutputStream := TFileStream.Create(
    TPath.Combine(GetCurrentDir, OUTPUT_FILE), fmCreate);
  Encoding := TEncoding.UTF8;
  Stopwatch := TStopwatch.StartNew;
  try
    Total := 0;
    while Generator.Next do
    begin
      Inc(Total);

      // Build "n1,n2,n3,n4,n5,n6,n7" directly - faster than string concatenation
      // or Format(), since this line runs 5,379,616 times.
      RowText := IntToStr(Generator.FIndices[0]);
      for k := 1 to PICK_COUNT - 1 do
        RowText := RowText + ',' + IntToStr(Generator.FIndices[k]);

      Buffer.Append(RowText);
      Buffer.Append(sLineBreak);

      // Periodically flush the buffer to disk so memory usage stays flat
      // instead of growing to hold all 5+ million lines at once.
      if Buffer.Length >= FLUSH_THRESHOLD then
      begin
        Bytes := Encoding.GetBytes(Buffer.ToString);
        OutputStream.WriteBuffer(Bytes[0], Length(Bytes));
        Buffer.Clear;
      end;

      if Total mod 500000 = 0 then
        WriteLn(Format('  %12d / %d combinations written (%.1f sec elapsed)',
          [Total, 5379616, Stopwatch.Elapsed.TotalSeconds]));
    end;

    // Flush whatever remains in the buffer.
    if Buffer.Length > 0 then
    begin
      Bytes := Encoding.GetBytes(Buffer.ToString);
      OutputStream.WriteBuffer(Bytes[0], Length(Bytes));
    end;

    Stopwatch.Stop;
    WriteLn;
    WriteLn(Format('Done. Wrote %d combinations in %.2f seconds.',
      [Total, Stopwatch.Elapsed.TotalSeconds]));
    WriteLn('Output file: ', TPath.Combine(GetCurrentDir, OUTPUT_FILE));
  finally
    OutputStream.Free;
    Buffer.Free;
    Generator.Free;
  end;
end;

begin
  try
    GenerateAllCombinations;
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;

{$IFDEF DEBUG}
  WriteLn('Press Enter to exit...');
  ReadLn;
{$ENDIF}
end.
