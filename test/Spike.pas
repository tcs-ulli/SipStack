unit Spike;

interface

uses
  Classes, Controls, ExtCtrls, Forms, IdSdp, IdSipCore, IdSipMessage,
  IdSipTransaction, IdSipTransport, StdCtrls, SyncObjs;

type
  TrnidSpike = class(TForm,
                     IIdSipDataListener,
                     IIdSipObserver,
                     IIdSipSessionListener,
                     IIdSipTransportListener,
                     IIdSipTransportSendingListener)
    Log: TMemo;
    Panel1: TPanel;
    Label1: TLabel;
    SessionCounter: TLabel;
    Label2: TLabel;
    RTPDataCount: TLabel;
    UiTimer: TTimer;
    TargetUri: TEdit;
    Invite: TButton;
    Bye: TButton;
    Label3: TLabel;
    UDPDataCount: TLabel;
    procedure UiTimerTimer(Sender: TObject);
    procedure InviteClick(Sender: TObject);
    procedure ByeClick(Sender: TObject);
  private
    RTPByteCount: Integer;
    UDPByteCount: Integer;
    DataStore:    TStream;
    Dispatch:     TIdSipTransactionDispatcher;
    Lock:         TCriticalSection;
    Transport:    TIdSipTransport;
    UA:           TIdSipUserAgentCore;

    procedure LogMessage(const Msg: TIdSipMessage);
    procedure OnChanged(const Observed: TObject);
    procedure OnEstablishedSession(const Session: TIdSipSession);
    procedure OnEndedSession(const Session: TIdSipSession);
    procedure OnModifiedSession(const Session: TIdSipSession;
                                const Invite: TIdSipRequest);
    procedure OnNewData(const Data: TStream);
    procedure OnNewUdpData(const Data: TStream);
    procedure OnNewSession(const Session: TIdSipSession);
    procedure OnReceiveRequest(const Request: TIdSipRequest;
                               const Transport: TIdSipTransport);
    procedure OnReceiveResponse(const Response: TIdSipResponse;
                                const Transport: TIdSipTransport);
    procedure OnSendRequest(const Request: TIdSipRequest;
                            const Transport: TIdSipTransport);
    procedure OnSendResponse(const Response: TIdSipResponse;
                             const Transport: TIdSipTransport);
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  end;

var
  rnidSpike: TrnidSpike;

implementation

{$R *.dfm}

uses
  IdGlobal, IdSipConsts, IdSipHeaders, IdSocketHandle, IdStack, SysUtils;

//******************************************************************************
//* TrnidSpike                                                                 *
//******************************************************************************
//* TrnidSpike Public methods **************************************************

constructor TrnidSpike.Create(AOwner: TComponent);
var
  Binding: TIdSocketHandle;
  Contact: TIdSipContactHeader;
  From:    TIdSipFromHeader;
begin
  inherited Create(AOwner);

  Self.RTPByteCount := 0;
  Self.DataStore := TFileStream.Create('..\etc\dump.wav', fmCreate or fmShareDenyWrite);
  Self.Lock      := TCriticalSection.Create;

  Self.Transport := TIdSipUdpTransport.Create(IdPORT_SIP);
  Binding := Self.Transport.Bindings.Add;
  Binding.IP := GStack.LocalAddress;
  Binding.Port := IdPORT_SIP;
  Self.Transport.HostName := Binding.IP;

  Self.Transport.AddTransportListener(Self);
  Self.Transport.AddTransportSendingListener(Self);
  Self.Dispatch := TIdSipTransactionDispatcher.Create;
  Self.Dispatch.AddTransport(Self.Transport);

  Self.UA := TIdSipUserAgentCore.Create;
  Self.UA.Dispatcher := Self.Dispatch;
  Self.UA.AddSessionListener(Self);
  Self.UA.AddObserver(Self);
  Self.UA.HostName := Self.Transport.HostName;
  Self.UA.UserAgentName := 'X-Lite build 1086';

  Contact := TIdSipContactHeader.Create;
  try
    Contact.Value := 'sip:franks@' + Self.Transport.HostName;
    Self.UA.Contact := Contact;
  finally
    Contact.Free;
  end;

  From := TIdSipFromHeader.Create;
  try
    From.Value := 'sip:franks@' + Self.Transport.HostName;
    Self.UA.From := From;
  finally
    From.Free;
  end;

  Self.Transport.Start;
end;

destructor TrnidSpike.Destroy;
begin
  Self.Transport.Stop;

  Self.UA.Free;
  Self.Dispatch.Free;
  Self.Transport.Free;

  Self.DataStore.Free;

  inherited Destroy;
end;

//* TrnidSpike Private methods *************************************************

procedure TrnidSpike.LogMessage(const Msg: TIdSipMessage);
begin
  Self.Log.Lines.Add(Msg.AsString);
  Self.Log.Lines.Add('----');
end;

procedure TrnidSpike.OnChanged(const Observed: TObject);
begin
  Self.SessionCounter.Caption := IntToStr((Observed as TIdSipUserAgentCore).SessionCount);
end;

procedure TrnidSpike.OnEstablishedSession(const Session: TIdSipSession);
begin
end;

procedure TrnidSpike.OnEndedSession(const Session: TIdSipSession);
begin
end;

procedure TrnidSpike.OnModifiedSession(const Session: TIdSipSession;
                                       const Invite: TIdSipRequest);
begin
end;

procedure TrnidSpike.OnNewData(const Data: TStream);
begin
  Self.Lock.Acquire;
  try
    Inc(Self.RTPByteCount, Data.Size);

    Self.DataStore.CopyFrom(Data, 0);
  finally
    Self.Lock.Release;
  end;
end;

procedure TrnidSpike.OnNewUdpData(const Data: TStream);
begin
  Self.Lock.Acquire;
  try
    Inc(Self.UDPByteCount, Data.Size);
  finally
    Self.Lock.Release;
  end;
end;

procedure TrnidSpike.OnNewSession(const Session: TIdSipSession);
begin
  Session.AcceptCall;
  Session.AddDataListener(Self);
end;

procedure TrnidSpike.OnReceiveRequest(const Request: TIdSipRequest;
                                      const Transport: TIdSipTransport);
begin
  Self.LogMessage(Request);
end;

procedure TrnidSpike.OnReceiveResponse(const Response: TIdSipResponse;
                                       const Transport: TIdSipTransport);
begin
  Self.LogMessage(Response);
end;

procedure TrnidSpike.OnSendRequest(const Request: TIdSipRequest;
                                   const Transport: TIdSipTransport);
begin
  Self.LogMessage(Request);
end;

procedure TrnidSpike.OnSendResponse(const Response: TIdSipResponse;
                                    const Transport: TIdSipTransport);
begin
  Self.LogMessage(Response);
end;

//* TrnidSpike Published methods ***********************************************

procedure TrnidSpike.UiTimerTimer(Sender: TObject);
begin
  Self.Lock.Acquire;
  try
    RTPDataCount.Caption := IntToStr(Self.RTPByteCount);
    UDPDataCount.Caption := IntToStr(Self.UDPByteCount);
  finally
    Self.Lock.Release;
  end;
end;

procedure TrnidSpike.InviteClick(Sender: TObject);
var
  Target: TIdSipToHeader;
begin
  Target := TIdSipToHeader.Create;
  try
    Target.Value := Self.TargetUri.Text;

    Self.UA.Call(Target);
  finally
    Target.Free;
  end;
end;

procedure TrnidSpike.ByeClick(Sender: TObject);
begin
  Self.UA.TerminateAllSessions;
end;

end.
