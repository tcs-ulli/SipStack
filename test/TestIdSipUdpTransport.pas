{
  (c) 2006 Directorate of New Technologies, Royal National Institute for Deaf people (RNID)

  The RNID licence covers this unit. Read the licence at:
      http://www.ictrnid.org.uk/docs/gw/rnid_license.txt

  This unit contains code written by:
    * Frank Shearar
}
unit TestIdSipUdpTransport;

interface

uses
  IdSipMessage, IdSipMockTransport, IdSipTransport, IdSipUdpTransport,
  IdTimerQueue, IdUdpClient, SyncObjs, SysUtils, TestFrameworkSip,
  TestFrameworkSipTransport;

type
  TestTIdSipUDPTransport = class(TestTIdSipTransport)
  private
    RPort: Cardinal;

    procedure CheckMessageWithTrailingGarbage(Sender: TObject;
                                              R: TIdSipRequest;
                                              ReceivedFrom: TIdSipConnectionBindings);
    procedure CheckRportParamFilledIn(Sender: TObject;
                                      R: TIdSipRequest;
                                      ReceivedFrom: TIdSipConnectionBindings);
    procedure CheckLeaveNonRportRequestsUntouched(Sender: TObject;
                                                  R: TIdSipRequest;
                                                  ReceivedFrom: TIdSipConnectionBindings);
    procedure CheckMissingContentLength(Sender: TObject;
                                        R: TIdSipRequest;
                                        ReceivedFrom: TIdSipConnectionBindings);
    procedure NoteSourcePort(Sender: TObject;
                             R: TIdSipRequest;
                             ReceivedFrom: TIdSipConnectionBindings);
  protected
    procedure CheckServerOnPort(const Host: String;
                                Port: Cardinal;
                                const Msg: String); override;
    procedure SendMessage(Msg: String); override;
    function  TransportType: TIdSipTransportClass; override;
  published
    procedure TestGetTransportType;
    procedure TestIsReliable;
    procedure TestIsSecure;
    procedure TestLeaveNonRportRequestsUntouched;
    procedure TestMessageWithTrailingGarbage;
    procedure TestMissingContentLength;
    procedure TestRportParamFilledIn;
    procedure TestRportListening;
  end;

  TestTIdSipUdpServer = class(TTestCaseSip,
                              IIdSipTransportListener)
  private
    CheckReceivedRequest:     TIdSipRequestEvent;
    CheckReceivedResponse:    TIdSipResponseEvent;
    Client:                   TIdUDPClient;
    EmptyListEvent:           TEvent;
    NotifiedMalformedMessage: Boolean;
    Parser:                   TIdSipParser;
    ReceivedResponse:         Boolean;
    Server:                   TIdSipUdpServer;
    Timer:                    TIdThreadedTimerQueue;
    Transport:                TIdSipMockTransport;

    procedure AcknowledgeEvent(Sender: TObject;
                               Request: TIdSipRequest;
                               ReceivedFrom: TIdSipConnectionBindings); overload;
    procedure AcknowledgeEvent(Sender: TObject;
                               Response: TIdSipResponse;
                               ReceivedFrom: TIdSipConnectionBindings); overload;
    procedure CheckRejectFragmentedRequestProperly(Sender: TObject;
                                                   Request: TIdSipRequest;
                                                   ReceivedFrom: TIdSipConnectionBindings);
    procedure CheckRejectFragmentedResponseProperly(Sender: TObject;
                                                    Response: TIdSipResponse;
                                                    ReceivedFrom: TIdSipConnectionBindings);
    procedure OnEmpty(Sender: TIdTimerQueue);
    procedure OnException(FailedMessage: TIdSipMessage;
                          E: Exception;
                          const Reason: String); overload;
    procedure OnReceiveRequest(Request: TIdSipRequest;
                               Receiver: TIdSipTransport;
                               Source: TIdSipConnectionBindings);
    procedure OnReceiveResponse(Response: TIdSipResponse;
                                Receiver: TIdSipTransport;
                                Source: TIdSipConnectionBindings);
    procedure OnRejectedMessage(const Msg: String;
                                const Reason: String);

  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNotifyFragmentedRequestProperly;
    procedure TestReceiveRequest;
    procedure TestReceiveResponse;
  end;

const
  BasicRequest = 'INVITE sip:wintermute@tessier-ashpool.co.luna SIP/2.0'#13#10
               + 'Via: SIP/2.0/TCP %s;branch=z9hG4bK776asdhds'#13#10
               + 'Max-Forwards: 70'#13#10
               + 'To: Wintermute <sip:wintermute@tessier-ashpool.co.luna>'#13#10
               + 'From: Case <sip:case@fried.neurons.org>;tag=1928301774'#13#10
               + 'Call-ID: a84b4c76e66710@gw1.leo-ix.org'#13#10
               + 'CSeq: 314159 INVITE'#13#10
               + 'Contact: <sip:wintermute@tessier-ashpool.co.luna>'#13#10
               + 'Content-Type: text/plain'#13#10
               + 'Content-Length: 29'#13#10
               + #13#10
               + 'I am a message. Hear me roar!';
  ViaFQDN        = 'gw1.leo-ix.org';
  ViaIP          = '127.0.0.1';
  ViaDifferentIP = '196.25.1.1';
  DefaultTimeout = 5000;

implementation

uses
  IdSipConsts, IdSocketHandle, IdUdpServer, TestFramework, TestMessages;

function Suite: ITestSuite;
begin
  Result := TTestSuite.Create('IdSipTcpTransport unit tests');
  Result.AddTest(TestTIdSipUDPTransport.Suite);
  Result.AddTest(TestTIdSipUdpServer.Suite);
end;

//******************************************************************************
//* TestTIdSipUDPTransport                                                     *
//******************************************************************************
//* TestTIdSipUDPTransport Protected methods ***********************************

procedure TestTIdSipUDPTransport.CheckServerOnPort(const Host: String;
                                                   Port: Cardinal;
                                                   const Msg: String);
var
  Binding: TIdSocketHandle;
  Server:  TIdUdpServer;
begin
  try
    Server := TIdUdpServer.Create(nil);
    try
      Binding := Server.Bindings.Add;
      Binding.IP    := Host;
      Binding.Port  := Port;
      Server.Active := true;
      try
        // Do nothing
      finally
        Server.Active := false;
      end;
    finally
      Server.Free;
    end;
    Fail('No server running on ' + Host + ': ' + IntToStr(Port) + '; ' + Msg);
  except
    on EIdCouldNotBindSocket do;
  end;
end;

procedure TestTIdSipUDPTransport.SendMessage(Msg: String);
var
  Client: TIdUdpClient;
begin
  Client := TIdUdpClient.Create(nil);
  try
    Client.Host := Self.HighPortTransport.Bindings[0].IP;
    Client.Port := Self.HighPortTransport.Bindings[0].Port;

    Client.Send(Msg);
  finally
    Client.Free;
  end;
end;

function TestTIdSipUDPTransport.TransportType: TIdSipTransportClass;
begin
  Result := TIdSipUdpTransport;
end;

//* TestTIdSipUDPTransport Private methods *************************************

procedure TestTIdSipUDPTransport.CheckMessageWithTrailingGarbage(Sender: TObject;
                                                                 R: TIdSipRequest;
                                                                 ReceivedFrom: TIdSipConnectionBindings);
begin
  Self.Request.Body := R.Body;
  
  Self.ThreadEvent.SetEvent;
end;

procedure TestTIdSipUDPTransport.CheckRportParamFilledIn(Sender: TObject;
                                                         R: TIdSipRequest;
                                                         ReceivedFrom: TIdSipConnectionBindings);
begin
  CheckNotEquals('',
                 R.LastHop.Params[RPortParam],
                 'Transport didn''t fill in the rport param');

  Self.NoteSourcePort(Sender, R, ReceivedFrom);
end;

procedure TestTIdSipUDPTransport.CheckLeaveNonRportRequestsUntouched(Sender: TObject;
                                                                     R: TIdSipRequest;
                                                                     ReceivedFrom: TIdSipConnectionBindings);
begin
  try
    Check(not R.LastHop.HasRport, 'rport param added by transport');
    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

procedure TestTIdSipUDPTransport.CheckMissingContentLength(Sender: TObject;
                                                           R: TIdSipRequest;
                                                           ReceivedFrom: TIdSipConnectionBindings);
begin
  try
    Check(R.HasHeader(ContentLengthHeaderFull),
          'Content-Length not added');
    CheckEquals('foofoo',
                R.Body,
                'Body');
    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

procedure TestTIdSipUDPTransport.NoteSourcePort(Sender: TObject;
                                                R: TIdSipRequest;
                                                ReceivedFrom: TIdSipConnectionBindings);
begin
  try
    Self.RPort := R.LastHop.RPort;
    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

//* TestTIdSipUDPTransport Published methods ***********************************

procedure TestTIdSipUDPTransport.TestGetTransportType;
begin
  CheckEquals(UdpTransport,
              Self.HighPortTransport.GetTransportType,
              'Transport type');
end;

procedure TestTIdSipUDPTransport.TestIsReliable;
begin
  Check(not Self.HighPortTransport.IsReliable,
        'UDP transport not marked as unreliable');
end;

procedure TestTIdSipUDPTransport.TestIsSecure;
begin
  Check(not Self.HighPortTransport.IsSecure,
        'UDP transport marked as secure');
end;

procedure TestTIdSipUDPTransport.TestLeaveNonRportRequestsUntouched;
begin
  Self.CheckingRequestEvent := Self.CheckLeaveNonRportRequestsUntouched;
  Self.LowPortTransport.Send(Self.Request, Self.HighPortLocation);

  Self.WaitForSignaled;  

  CheckEquals(0, Self.RPort, 'rport value');
end;

procedure TestTIdSipUDPTransport.TestMessageWithTrailingGarbage;
var
  Body:   String;
  Client: TIdUdpClient;
begin
  Self.CheckingRequestEvent := Self.CheckMessageWithTrailingGarbage;
  Body := 'I am a message. Hear me roar!';

  Client := TIdUdpClient.Create(nil);
  try
    Client.Host := Self.HighPortTransport.Bindings[0].IP;
    Client.Port := Self.HighPortTransport.Bindings[0].Port;

    Client.Send('INVITE sip:wintermute@tessier-ashpool.co.luna SIP/2.0'#13#10
              + 'Via: SIP/2.0/TCP proxy.tessier-ashpool.co.luna;branch=z9hG4bK776asdhds'#13#10
              + 'Max-Forwards: 70'#13#10
              + 'To: Wintermute <sip:wintermute@tessier-ashpool.co.luna>'#13#10
              + 'From: Case <sip:case@fried.neurons.org>;tag=1928301774'#13#10
              + 'Call-ID: a84b4c76e66710@gw1.leo-ix.org'#13#10
              + 'CSeq: 314159 INVITE'#13#10
              + 'Contact: <sip:wintermute@tessier-ashpool.co.luna>'#13#10
              + 'Content-Type: text/plain'#13#10
              + 'Content-Length: ' + IntToStr(Length(Body)) + #13#10
              + #13#10
              + Body + #0#0#0#0#0);

    Self.ExceptionMessage := Self.HighPortTransport.ClassName
        + ': We rejected a message with a Content-Length that had trailing '
        + 'octets';
    Self.WaitForSignaled;
    CheckEquals(Body,
                Self.Request.Body,
                'Body of message');
  finally
    Client.Free;
  end;
end;

procedure TestTIdSipUDPTransport.TestMissingContentLength;
begin
  // No Content-Length header? Assume that the entire rest of the UDP packet is
  // the body.
  Self.CheckingRequestEvent := Self.CheckMissingContentLength;

  Self.SendMessage('INVITE sip:foo SIP/2.0'#13#10
                 + 'Via: SIP/2.0/UDP 127.0.0.1;branch=' + BranchMagicCookie + 'f00L'#13#10
                 + 'Call-ID: foo'#13#10
                 + 'CSeq: 1 INVITE'#13#10
                 + 'From: sip:foo'#13#10
                 + 'To: sip:foo'#13#10
                 + 'Max-Forwards: 70'#13#10
                 + #13#10
                 + 'foofoo');

  Self.WaitForSignaled;
end;

procedure TestTIdSipUDPTransport.TestRportParamFilledIn;
begin
  Self.CheckingRequestEvent := Self.CheckRportParamFilledIn;
  Self.Request.LastHop.Params[RportParam] := '';
  Self.LowPortTransport.Send(Self.Request, Self.HighPortLocation);

  Self.WaitForSignaled;

  CheckNotEquals(0, Self.RPort, 'rport value');
end;

procedure TestTIdSipUDPTransport.TestRportListening;
var
  Binding: TIdSocketHandle;
  Server:  TIdUdpServer;
begin
  // We test here that when a request is sent from port x, that we listen on
  // port x for responses, as per RFC 3581
  Self.CheckingRequestEvent := Self.NoteSourcePort;
  Self.Request.LastHop.Params[RportParam] := '';
  Self.LowPortTransport.Send(Self.Request, Self.HighPortLocation);

  Self.WaitForSignaled;

  Server := TIdUdpServer.Create(nil);
  try
    try
      Binding := Server.Bindings.Add;
      Binding.IP   := Self.LowPortTransport.Bindings[0].IP;
      Binding.Port := Self.RPort;

      Server.Active := true;
      Fail('Server wasn''t listening on the port from which it sent an rport'
         + ' request');
    except
      on EIdCouldNotBindSocket do;
    end;
  finally
    Server.Free;
  end;
end;

//*******************************************************************************
//* TestTIdSipUdpServer                                                         *
//*******************************************************************************
//* TestTIdSipUdpServer Public methods ******************************************

procedure TestTIdSipUdpServer.SetUp;
var
  Binding: TIdSocketHandle;
begin
  inherited SetUp;

  Self.EmptyListEvent := TSimpleEvent.Create;
  Self.Timer := TIdThreadedTimerQueue.Create(false);
  Self.Timer.OnEmpty := Self.OnEmpty;

  Self.Transport := TIdSipMockUdpTransport.Create;
  Self.Transport.AddTransportListener(Self);

  Self.Client := TIdUDPClient.Create(nil);
  Self.Server := TIdSipUdpServer.Create(nil);
  Self.Server.Timer := Self.Timer;
  Self.Server.TransportID := Self.Transport.ID;
  Self.Server.Bindings.Clear;
  Binding := Self.Server.Bindings.Add;
  Binding.IP := '127.0.0.1';
  Binding.Port := Server.DefaultPort;

  Self.Server.Active := true;
  Self.Client.Host := '127.0.0.1';
  Self.Client.Port := Server.DefaultPort;

  Self.Parser := TIdSipParser.Create;

  Self.NotifiedMalformedMessage := false;
end;

procedure TestTIdSipUdpServer.TearDown;
var
  WaitTime: Cardinal;
begin
  // Wait for all scheduled events to execute
  WaitTime := Self.Timer.DefaultTimeout * 3 div 2;

  Self.Timer.Terminate;
  Self.EmptyListEvent.WaitFor(WaitTime);

  Self.Parser.Free;

  Self.Server.Active := false;

  Self.Server.Free;
  Self.Client.Free;
  
  Self.EmptyListEvent.Free;
  Self.Transport.Free;

  inherited TearDown;
end;

//* TestTIdSipUdpServer Private methods *****************************************

procedure TestTIdSipUdpServer.AcknowledgeEvent(Sender: TObject;
                                               Request: TIdSipRequest;
                                               ReceivedFrom: TIdSipConnectionBindings);
begin
  Self.ThreadEvent.SetEvent;
end;

procedure TestTIdSipUdpServer.AcknowledgeEvent(Sender: TObject;
                                               Response: TIdSipResponse;
                                               ReceivedFrom: TIdSipConnectionBindings);
begin
  Self.ThreadEvent.SetEvent;
end;

procedure TestTIdSipUdpServer.CheckRejectFragmentedRequestProperly(Sender: TObject;
                                                                   Request: TIdSipRequest;
                                                                   ReceivedFrom: TIdSipConnectionBindings);
begin
  try
    Check(Request.IsMalformed,
          'Fragment (that looks like a request) not marked as malformed');

    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

procedure TestTIdSipUdpServer.CheckRejectFragmentedResponseProperly(Sender: TObject;
                                                                    Response: TIdSipResponse;
                                                                    ReceivedFrom: TIdSipConnectionBindings);
begin
  try
    Check(Response.IsMalformed,
          'Fragment (that by default looks like a response) not marked as malformed');

    Self.ThreadEvent.SetEvent;
  except
    on E: Exception do begin
      Self.ExceptionType    := ExceptClass(E.ClassType);
      Self.ExceptionMessage := E.Message;
    end;
  end;
end;

procedure TestTIdSipUdpServer.OnEmpty(Sender: TIdTimerQueue);
begin
  Self.EmptyListEvent.SetEvent;
end;

procedure TestTIdSipUdpServer.OnException(FailedMessage: TIdSipMessage;
                                          E: Exception;
                                          const Reason: String);
begin
end;

procedure TestTIdSipUdpServer.OnReceiveRequest(Request: TIdSipRequest;
                                               Receiver: TIdSipTransport;
                                               Source: TIdSipConnectionBindings);
begin
  if Assigned(Self.CheckReceivedRequest) then
    Self.CheckReceivedRequest(Self, Request, Source);
end;

procedure TestTIdSipUdpServer.OnReceiveResponse(Response: TIdSipResponse;
                                                Receiver: TIdSipTransport;
                                                Source: TIdSipConnectionBindings);
begin
  if Assigned(Self.CheckReceivedResponse) then
    Self.CheckReceivedResponse(Self, Response, Source);
  Self.ReceivedResponse := true;

  Self.ThreadEvent.SetEvent;
end;

procedure TestTIdSipUdpServer.OnRejectedMessage(const Msg: String;
                                                const Reason: String);
begin
  Self.NotifiedMalformedMessage := true;
  Self.ThreadEvent.SetEvent;
end;

//* TestTIdSipUdpServer Published methods ***************************************

procedure TestTIdSipUdpServer.TestNotifyFragmentedRequestProperly;
var
  Divider: Integer;
  Msg:     String;
begin
  Self.CheckReceivedRequest  := Self.CheckRejectFragmentedRequestProperly;
  Self.CheckReceivedResponse := Self.CheckRejectFragmentedResponseProperly;

  Msg := Format(BasicRequest, [Self.Server.Bindings[0].IP]);

  Divider := Length(Msg) div 2;

  Self.Client.Send(Copy(Msg, 1, Divider));

  Self.WaitForSignaled;
  Self.ThreadEvent.ResetEvent;

  Self.Client.Send(Copy(Msg, Divider + 1, Length(Msg)));
  Self.WaitForSignaled;
end;

procedure TestTIdSipUdpServer.TestReceiveRequest;
var
  SentRequest: TIdSipRequest;
begin
  Self.CheckReceivedRequest := Self.AcknowledgeEvent;

  Self.Client.Send(BasicRequest);
  Self.WaitForSignaled;

  Check(nil <> Self.Transport.LastRequest,
        'Transport didn''t receive a request');

  SentRequest := TIdSipRequest.ReadRequestFrom(BasicRequest);
  try
    Check(SentRequest.Equals(Self.Transport.LastRequest),
          'What the client sent isn''t what the transport received');
  finally
    SentRequest.Free;
  end;
end;

procedure TestTIdSipUdpServer.TestReceiveResponse;
var
  SentResponse: TIdSipResponse;
begin
  Self.CheckReceivedResponse := Self.AcknowledgeEvent;

  Self.Client.Send(BasicResponse);
  Self.WaitForSignaled;

  Check(nil <> Self.Transport.LastResponse,
        'Transport didn''t receive a Response');

  SentResponse := TIdSipResponse.ReadResponseFrom(BasicResponse);
  try
    Check(SentResponse.Equals(Self.Transport.LastResponse),
          'What the client sent isn''t what the transport received');
  finally
    SentResponse.Free;
  end;
end;

initialization
  RegisterTest('UDP Transport', Suite);
end.
