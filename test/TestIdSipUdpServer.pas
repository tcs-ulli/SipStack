unit TestIdSipUdpServer;

interface

uses
  Classes, IdSipParser, IdSipUdpServer, IdUDPClient, SysUtils, TestFrameworkEx;

type
  TestTIdSipUdpServer = class(TThreadingTestCase)
  private
    Client: TIdUDPClient;
    Server: TIdSipUdpServer;

    procedure CheckRequest(Sender: TObject; const Request: TIdSipRequest);
    procedure CheckResponse(Sender: TObject; const Response: TIdSipResponse);
    procedure CheckTortureTest21(Sender: TObject; const Response: TIdSipResponse);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestMalformedRequest;
    procedure TestMalformedResponse;
    procedure TestRequest;
    procedure TestResponse;
    procedure TestTortureTest21;
  end;

const
  DefaultTimeout = 5000;

implementation

uses
  SyncObjs, TestFramework, TortureTests;

function Suite: ITestSuite;
begin
  Result := TTestSuite.Create('IdSipUdpServer unit tests');
  Result.AddTest(TestTIdSipUdpServer.Suite);
end;

//*******************************************************************************
//* TestTIdSipUdpServer                                                         *
//*******************************************************************************
//* TestTIdSipUdpServer Public methods ******************************************

procedure TestTIdSipUdpServer.SetUp;
begin
  inherited SetUp;

  Client := TIdUDPClient.Create(nil);
  Server := TIdSipUdpServer.Create(nil);

  Server.Active := true;
  Client.Host := '127.0.0.1';
  Client.Port := Server.DefaultPort;
end;

procedure TestTIdSipUdpServer.TearDown;
begin
  Server.Active := false;

  Server.Free;
  Client.Free;

  inherited TearDown;
end;

//* TestTIdSipUdpServer Private methods *****************************************

procedure TestTIdSipUdpServer.CheckRequest(Sender: TObject; const Request: TIdSipRequest);
begin
  try
    CheckEquals(MethodInvite, Request.Method,             'Method');
    CheckEquals('SIP/2.0',    Request.SipVersion,         'SipVersion');
    CheckEquals(29,           Request.ContentLength,      'ContentLength');
    CheckEquals(70,           Request.MaxForwards,        'Max-Forwards');
{
  CheckEquals('Via: SIP/2.0/TCP gw1.leo_ix.org;branch=z9hG4bK776asdhds',
              Request.OtherHeaders[0],
              'OtherHeaders[0]');
  CheckEquals('To: Wintermute <sip:wintermute@tessier-ashpool.co.lu>',
              Request.OtherHeaders[1],
              'OtherHeaders[1]');
  CheckEquals('From: Case <sip:case@fried.neurons.org>;tag=1928301774',
              Request.OtherHeaders[2],
              'OtherHeaders[2]');
  CheckEquals('Call-ID: a84b4c76e66710@gw1.leo_ix.org',
              Request.OtherHeaders[3],
              'OtherHeaders[3]');
  CheckEquals('CSeq: 314159 INVITE',
              Request.OtherHeaders[4],
              'OtherHeaders[4]');
  CheckEquals('Contact: <sip:wintermute@tessier-ashpool.co.lu>',
              Request.OtherHeaders[5],
              'OtherHeaders[5]');
  CheckEquals(6, Request.OtherHeaders.Count, 'OtherHeaders Count');
}
  CheckEquals('I am a message. Hear me roar!', Request.Body, 'Body');

    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

procedure TestTIdSipUdpServer.CheckResponse(Sender: TObject; const Response: TIdSipResponse);
begin
  try
    CheckEquals('SIP/2.0',                       Response.SipVersion,    'SipVersion');
    CheckEquals(486,                             Response.StatusCode,    'StatusCode');
    CheckEquals('Busy Here',                     Response.StatusText,    'StatusText');
    CheckEquals('a84b4c76e66710@gw1.leo_ix.org', Response.CallID,        'CallID');
    CheckEquals(29,                              Response.ContentLength, 'ContentLength');
    CheckEquals(70,                              Response.MaxForwards,   'MaxForwards');

  CheckEquals('Via: SIP/2.0/TCP gw1.leo_ix.org;branch=z9hG4bK776asdhds',
              Response.Headers.Items[0].AsString,
              'Headers.Items[0].AsString');
  CheckEquals('Max-Forwards: 70',
              Response.Headers.Items[1].AsString,
              'Headers.Items[1].AsString');
  CheckEquals('To: Wintermute <sip:wintermute@tessier-ashpool.co.lu>',
              Response.Headers.Items[2].AsString,
              'Headers.Items[2].AsString');
  CheckEquals('From: Case <sip:case@fried.neurons.org>;tag=1928301774',
              Response.Headers.Items[3].AsString,
              'Headers.Items[3].AsString');
  CheckEquals('Call-ID: a84b4c76e66710@gw1.leo_ix.org',
              Response.Headers.Items[4].AsString,
              'Headers.Items[4].AsString');
  CheckEquals('CSeq: 314159 INVITE',
              Response.Headers.Items[5].AsString,
              'Headers.Items[5].AsString');
  CheckEquals('Contact: <sip:wintermute@tessier-ashpool.co.lu>',
              Response.Headers.Items[6].AsString,
              'Headers.Items[6].AsString');
  CheckEquals('Content-Length: 29',
              Response.Headers.Items[7].AsString,
              'Headers.Items[7].AsString');
  CheckEquals(8, Response.Headers.Count, 'OtherHeaders Count');

  CheckEquals('I am a message. Hear me roar!', Response.Body, 'Body');

    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

procedure TestTIdSipUdpServer.CheckTortureTest21(Sender: TObject; const Response: TIdSipResponse);
begin
  try
    CheckEquals(SipVersion,                Response.SipVersion, 'SipVersion');
    CheckEquals(400,                       Response.StatusCode, 'StatusCode');
    CheckEquals(RequestUriNoAngleBrackets, Response.StatusText, 'StatusText');

    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

//* TestTIdSipUdpServer Published methods ***************************************

procedure TestTIdSipUdpServer.TestMalformedRequest;
var
  Expected: TStrings;
  Received: TStrings;
  Msg:      TIdSipMessage;
  P:        TIdSipParser;
begin
  // note the semicolon in the SIP-version
  Client.Send('INVITE sip:wintermute@tessier-ashpool.co.lu SIP/;2.0'#13#10
            + 'To: "Cthulhu" <tentacleface@rlyeh.org.au>'#13#10
            + 'From: "Great Old Ones" <greatoldones@outerdarkness.lu>'#13#10
            + 'CSeq: 0'#13#10
            + 'Call-ID: 0'#13#10
            + 'Max-Forwards: 5'#13#10
            + 'Via: SIP/2.0/UDP 127.0.0.1:5060'#13#10
            + #13#10);

  Expected := TStringList.Create;
  try
    P := TIdSipParser.Create;
    try
      Msg := P.MakeBadRequestResponse(Format(InvalidSipVersion, ['SIP/;2.0']));
      try
        Expected.Text := Msg.AsString;
      finally
        Msg.Free;
      end;
    finally
      P.Free;
    end;

    Received := TStringList.Create;
    try
      Received.Text := Client.ReceiveString(DefaultTimeout);

      CheckEquals(Expected, Received, 'Malformed request');
    finally
      Received.Free;
    end;
  finally
    Expected.Free;
  end;
end;

procedure TestTIdSipUdpServer.TestMalformedResponse;
begin
  Client.Send('SIP/;2.0 200 OK'#13#10
            + #13#10);
end;

procedure TestTIdSipUdpServer.TestRequest;
begin
  Server.OnRequest := Self.CheckRequest;

  Client.Send('INVITE sip:wintermute@tessier-ashpool.co.lu SIP/2.0'#13#10
            + 'Via: SIP/2.0/TCP gw1.leo_ix.org;branch=z9hG4bK776asdhds'#13#10
            + 'Max-Forwards: 70'#13#10
            + 'To: Wintermute <sip:wintermute@tessier-ashpool.co.lu>'#13#10
            + 'From: Case <sip:case@fried.neurons.org>;tag=1928301774'#13#10
            + 'Call-ID: a84b4c76e66710@gw1.leo_ix.org'#13#10
            + 'CSeq: 314159 INVITE'#13#10
            + 'Contact: <sip:wintermute@tessier-ashpool.co.lu>'#13#10
            + 'Content-Length: 29'#13#10
            + #13#10
            + 'I am a message. Hear me roar!');

  CheckEquals('', Client.ReceiveString(DefaultTimeout), 'Response to a malformed response');

  if (Self.ThreadEvent.WaitFor(DefaultTimeout) <> wrSignaled) then
    raise Self.ExceptionType.Create(Self.ExceptionMessage);
end;

procedure TestTIdSipUdpServer.TestResponse;
begin
  Server.OnResponse := Self.CheckResponse;

  Client.Send('SIP/2.0 486 Busy Here'#13#10
            + 'Via: SIP/2.0/TCP gw1.leo_ix.org;branch=z9hG4bK776asdhds'#13#10
            + 'Max-Forwards: 70'#13#10
            + 'To: Wintermute <sip:wintermute@tessier-ashpool.co.lu>'#13#10
            + 'From: Case <sip:case@fried.neurons.org>;tag=1928301774'#13#10
            + 'Call-ID: a84b4c76e66710@gw1.leo_ix.org'#13#10
            + 'CSeq: 314159 INVITE'#13#10
            + 'Contact: <sip:wintermute@tessier-ashpool.co.lu>'#13#10
            + 'Content-Length: 29'#13#10
            + #13#10
            + 'I am a message. Hear me roar!');

  if (Self.ThreadEvent.WaitFor(DefaultTimeout) <> wrSignaled) then
    raise Self.ExceptionType.Create(Self.ExceptionMessage);
end;

procedure TestTIdSipUdpServer.TestTortureTest21;
begin
  // http://www.ietf.org/internet-drafts/draft-ietf-sipping-torture-tests-00.txt section 2.21
  //   This INVITE is illegal because the Request-URI has been enclosed
  //   within in "<>".
  //   An intelligent server may be able to deal with this and fix up
  //   athe Request-URI if acting as a Proxy. If not it should respond 400
  //   with an appropriate reason phrase.
  Server.OnResponse := Self.CheckTortureTest21;

  Self.Client.Send(TortureTest21);
end;

initialization
  RegisterTest('SIP server using UDP', Suite);
end.
