unit IdSipTransaction;

interface

uses
  Contnrs, IdSipMessage, IdSipTimer, IdSipTransport;

const
  InitialT1     = 500;   // ms
  InitialT1_64  = 64*InitialT1;
  TimerDTimeout = 32000; // ms
  T2            = 4000;  // ms
  T4            = 5000;  // ms

const
  SessionTimeoutMsg = 'Timed out';

type
  TIdSipFailEvent = procedure(Sender: TObject; const Reason: String) of object;
  // This covers all states - INVITE, non-INVITE, client, server.
  TIdSipTransactionState = (itsCalling, itsCompleted, itsConfirmed,
                            itsProceeding, itsTerminated, itsTrying);

  TIdSipTransaction = class;
  TIdSipTransactionClass = class of TIdSipTransaction;

  // For the moment, Dispatcher does not manage lifetimes of transports.
  // Perhaps this might change...
  //
  // * Add RFC 2543 matching
  // * dispatch requests to the correct transaction
  // * dispatch responses to the correct transaction
  TIdSipTransactionDispatcher = class(TObject)
  private
    Transports:   TObjectList;
    Transactions: TObjectList;

    procedure DeliverToTransaction(const Request: TIdSipRequest); overload;
    procedure DeliverToTransaction(const Response: TIdSipResponse); overload;
    function  FindTransaction(const R: TIdSipRequest): TIdSipTransaction; overload;
    function  FindTransaction(const R: TIdSipResponse): TIdSipTransaction; overload;
    function  TransportAt(const Index: Integer): TIdSipAbstractTransport;
  protected
    procedure OnTransportRequest(Sender: TObject; const R: TIdSipRequest);
    procedure OnTransportResponse(Sender: TObject; const R: TIdSipResponse);
    function  FindAppropriateTransport(const M: TIdSipMessage): TIdSipAbstractTransport;
  public
    constructor Create; virtual;
    destructor  Destroy; override;

    procedure AddTransport(const Transport: TIdSipAbstractTransport);
    procedure ClearTransports;
    function  Match(const ReceivedRequest,
                          TranRequest: TIdSipRequest): Boolean; overload;
    function  Match(const ReceivedResponse: TIdSipResponse;
                    const TranRequest: TIdSipRequest): Boolean; overload;
    procedure SendRequest(const R: TIdSipRequest); virtual;
    procedure SendResponse(const R: TIdSipResponse); virtual;
    function  TransactionAt(const Index: Integer): TIdSipTransaction;
    function  TransactionCount: Integer;
    function  TransportCount: Integer;
    function  WillUseReliableTranport(const R: TIdSipMessage): Boolean;
  end;

  TIdSipMockTransactionDispatcher = class(TIdSipTransactionDispatcher)
  private
    fTransport: TIdSipMockTransport;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure SendRequest(const R: TIdSipRequest); override;
    procedure SendResponse(const R: TIdSipResponse); override;

    property Transport: TIdSipMockTransport read fTransport;
  end;

  TIdSipTransaction = class(TObject)
  private
    fInitialRequest:    TIdSipRequest;
    fOnFail:            TIdSipFailEvent;
    fOnReceiveRequest:  TIdSipRequestEvent;
    fOnReceiveResponse: TIdSipResponseEvent;
    fOnTerminated:      TIdSipNotifyEvent;
    fState:             TIdSipTransactionState;
    fDispatcher:        TIdSipTransactionDispatcher;
  protected
    procedure ChangeToCompleted(const R: TIdSipResponse); virtual;
    procedure ChangeToProceeding; overload;
    procedure ChangeToProceeding(const R: TIdSipRequest); overload; virtual;
    procedure ChangeToProceeding(const R: TIdSipResponse); overload; virtual;
    procedure ChangeToTerminated; virtual;
    procedure DoOnFail(const Reason: String); virtual;
    procedure DoOnReceiveRequest(const R: TIdSipRequest);
    procedure DoOnReceiveResponse(const R: TIdSipResponse);
    procedure DoOnTerminated;
    procedure SetState(const Value: TIdSipTransactionState);
    procedure TryResendInitialRequest;
    procedure TrySendRequest(const R: TIdSipRequest);
    procedure TrySendResponse(const R: TIdSipResponse); virtual;

    property InitialRequest: TIdSipRequest               read fInitialRequest;
    property Dispatcher:     TIdSipTransactionDispatcher read fDispatcher;
  public
    class function GetTransactionType(const Request: TIdSipRequest): TIdSipTransactionClass;

    constructor Create; virtual;

    procedure HandleRequest(const R: TIdSipRequest); virtual;
    procedure HandleResponse(const R: TIdSipResponse); virtual;
    procedure Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                         const InitialRequest: TIdSipRequest;
                         const Timeout:        Cardinal = InitialT1_64); virtual;

    property OnFail:            TIdSipFailEvent        read fOnFail write fOnFail;
    property OnReceiveRequest:  TIdSipRequestEvent     read fOnReceiveRequest write fOnReceiveRequest;
    property OnReceiveResponse: TIdSipResponseEvent    read fOnReceiveResponse write fOnReceiveResponse;
    property OnTerminated:      TIdSipNotifyEvent      read fOnTerminated write fOnTerminated;
    property State:             TIdSipTransactionState read fState;
  end;

  TIdSipClientInviteTransaction = class(TIdSipTransaction)
  private
    fTimeout: Cardinal;
    TimerA:   TIdSipTimer;
    TimerB:   TIdSipTimer;
    TimerD:   TIdSipTimer;

    procedure ChangeToCalling;
    procedure GenerateACK(const R:   TIdSipResponse;
                                Req: TIdSipRequest);
    procedure OnTimerA(Sender: TObject);
    procedure OnTimerB(Sender: TObject);
    procedure OnTimerD(Sender: TObject);
    procedure TrySendACK(const R: TIdSipResponse);
  protected
    procedure ChangeToCompleted(const R: TIdSipResponse); override;
    procedure ChangeToProceeding(const R: TIdSipResponse); override;
    procedure ChangeToTerminated; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure HandleResponse(const R: TIdSipResponse); override;
    procedure Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                         const InitialRequest: TIdSipRequest;
                         const Timeout:        Cardinal = InitialT1_64); override;

    property Timeout: Cardinal read fTimeout write fTimeout;
  end;

  TIdSipServerInviteTransaction = class(TIdSipTransaction)
  private
    LastProceedingResponseSent: Cardinal;
    TimerG:                     TIdSipTimer;
    TimerGHasFired:             Boolean;
    TimerH:                     TIdSipTimer;
    TimerI:                     TIdSipTimer;

    procedure ChangeToConfirmed(const R: TIdSipRequest);
    procedure Generate100(const R:   TIdSipRequest;
                                Res: TIdSipResponse);
    procedure GenerateResponse(const R:          TIdSipRequest;
                                     Res:        TIdSipResponse;
                               const StatusCode: Cardinal);
    procedure OnTimerG(Sender: TObject);
    procedure OnTimerH(Sender: TObject);
    procedure OnTimerI(Sender: TObject);
    procedure TrySend100Response(const R: TIdSipRequest);
    procedure TrySendLastResponse(const R: TIdSipRequest);
  protected
    procedure ChangeToCompleted(const R: TIdSipResponse); override;
    procedure ChangeToProceeding(const R: TIdSipRequest); overload; override;
    procedure ChangeToTerminated; override;
    procedure TrySendResponse(const R: TIdSipResponse); override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure HandleRequest(const R: TIdSipRequest); override;
    procedure HandleResponse(const R: TIdSipResponse); override;
    procedure Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                         const InitialRequest: TIdSipRequest;
                         const Timeout:        Cardinal = InitialT1_64); override;
  end;

  TIdSipClientNonInviteTransaction = class(TIdSipTransaction)
  private
    TimerE: TIdSipTimer;
    TimerF: TIdSipTimer;
    TimerK: TIdSipTimer;

    procedure OnTimerE(Sender: TObject);
    procedure OnTimerF(Sender: TObject);
    procedure OnTimerK(Sender: TObject);
  protected
    procedure ChangeToCompleted(const R: TIdSipResponse); override;
    procedure ChangeToProceeding(const R: TIdSipResponse); override;
    procedure ChangeToTrying;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure HandleResponse(const R: TIdSipResponse); override;
    procedure Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                         const InitialRequest: TIdSipRequest;
                         const Timeout:        Cardinal = InitialT1_64); override;
  end;

  TIdSipServerNonInviteTransaction = class(TIdSipTransaction)
  private
    LastProceedingResponseSent: Cardinal;
    TimerJ:                     TIdSipTimer;

    procedure ChangeToTrying(const R: TIdSipRequest);
    procedure GenerateResponse(const R:          TIdSipRequest;
                                     Res:        TIdSipResponse;
                               const StatusCode: Cardinal);
    procedure OnTimerJ(Sender: TObject);
    procedure TrySendLastResponse(const R: TIdSipRequest);
  protected
    procedure ChangeToCompleted(const R: TIdSipResponse); override;
    procedure ChangeToProceeding(const R: TIdSipResponse); override;
    procedure TrySendResponse(const R: TIdSipResponse); override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure HandleRequest(const R: TIdSipRequest); override;
    procedure HandleResponse(const R: TIdSipResponse); override;
    procedure Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                         const InitialRequest: TIdSipRequest;
                         const Timeout:        Cardinal = InitialT1_64); override;
  end;

implementation

uses
  IdException, IdSipConsts, IdSipHeaders, Math, SysUtils;

//******************************************************************************
//* TIdSipTransactionDispatcher                                                *
//******************************************************************************
//* TIdSipTransactionDispatcher Public methods *********************************

constructor TIdSipTransactionDispatcher.Create;
begin
  inherited Create;

  Self.Transports := TObjectList.Create(false);
  Self.Transactions := TObjectList.Create(true);
end;

destructor TIdSipTransactionDispatcher.Destroy;
begin
  Self.Transactions.Free;
  Self.Transports.Free;

  inherited Destroy;
end;

procedure TIdSipTransactionDispatcher.AddTransport(const Transport: TIdSipAbstractTransport);
begin
  Self.Transports.Add(Transport);
  Transport.OnRequest  := Self.OnTransportRequest;
  Transport.OnResponse := Self.OnTransportResponse;
end;

procedure TIdSipTransactionDispatcher.ClearTransports;
begin
  Self.Transports.Clear;
end;

function TIdSipTransactionDispatcher.Match(const ReceivedRequest,
                                                 TranRequest: TIdSipRequest): Boolean;
begin
  if ReceivedRequest.Path.LastHop.IsRFC3261Branch then begin
    Result := (ReceivedRequest.Path.LastHop.Branch = TranRequest.Path.LastHop.Branch)
          and (ReceivedRequest.Path.LastHop.SentBy = TranRequest.Path.LastHop.SentBy);

    if ReceivedRequest.IsACK then
      Result := Result and TranRequest.IsInvite
    else
      Result := Result and (ReceivedRequest.Method = TranRequest.Method);
  end
  else begin
    raise Exception.Create('matching of SIP/1.0 messages not implemented yet');
  end;
end;

function TIdSipTransactionDispatcher.Match(const ReceivedResponse: TIdSipResponse;
                                           const TranRequest:      TIdSipRequest): Boolean;
begin
  Result := (ReceivedResponse.Path.Length > 0)
        and (TranRequest.Path.Length > 0);

  Result := Result
        and (ReceivedResponse.Path.LastHop.Branch = TranRequest.Path.LastHop.Branch);

  if (ReceivedResponse.CSeq.Method = MethodAck) then
    Result := Result
          and (TranRequest.Method = MethodInvite)
  else
    Result := Result
          and (ReceivedResponse.CSeq.Method = TranRequest.Method);
end;

procedure TIdSipTransactionDispatcher.SendRequest(const R: TIdSipRequest);
begin
end;

procedure TIdSipTransactionDispatcher.SendResponse(const R: TIdSipResponse);
begin
end;

function TIdSipTransactionDispatcher.TransactionAt(const Index: Integer): TIdSipTransaction;
begin
  Result := Self.Transactions[Index] as TIdSipTransaction;
end;

function TIdSipTransactionDispatcher.TransactionCount: Integer;
begin
  Result := Self.Transactions.Count;
end;

function TIdSipTransactionDispatcher.TransportCount: Integer;
begin
  Result := Self.Transports.Count;
end;

function TIdSipTransactionDispatcher.WillUseReliableTranport(const R: TIdSipMessage): Boolean;
begin
  Assert(R.Path.Length > 0, 'Messages must have at least one Via header');

  Result := R.Path.LastHop.Transport <> sttUDP;
end;

//* TIdSipTransactionDispatcher Protected methods ******************************

procedure TIdSipTransactionDispatcher.OnTransportRequest(Sender: TObject; const R: TIdSipRequest);
begin
  Self.DeliverToTransaction(R);
end;

procedure TIdSipTransactionDispatcher.OnTransportResponse(Sender: TObject; const R: TIdSipResponse);
begin
  Self.DeliverToTransaction(R);
end;

function TIdSipTransactionDispatcher.FindAppropriateTransport(const M: TIdSipMessage): TIdSipAbstractTransport;
begin
  Result := nil;
end;

//* TIdSipTransactionDispatcher Private methods ********************************

procedure TIdSipTransactionDispatcher.DeliverToTransaction(const Request: TIdSipRequest);
var
  Tran: TIdSipTransaction;
begin
  Tran := Self.FindTransaction(Request);

  if (Tran = nil) then begin
    Tran := TIdSipTransaction.GetTransactionType(Request).Create;
    Self.Transactions.Add(Tran);
    Tran.Initialise(Self, Request);
  end;

  Tran.HandleRequest(Request);
end;

procedure TIdSipTransactionDispatcher.DeliverToTransaction(const Response: TIdSipResponse);
var
  Tran: TIdSipTransaction;
begin
  Tran := Self.FindTransaction(Response);

  // We drop unmatched responses on the floor
  if (Tran <> nil) then 
    Tran.HandleResponse(Response);
end;

function TIdSipTransactionDispatcher.FindTransaction(const R: TIdSipRequest): TIdSipTransaction;
var
  I: Integer;
begin
  Result := nil;

  I := 0;
  while (I < Self.Transactions.Count) and (Result = nil) do
    if Self.Match(R, Self.TransactionAt(I).InitialRequest) then
      Result := Self.TransactionAt(I)
    else Inc(I);
end;

function TIdSipTransactionDispatcher.FindTransaction(const R: TIdSipResponse): TIdSipTransaction;
var
  I: Integer;
begin
  Result := nil;

  I := 0;
  while (I < Self.Transactions.Count) and (Result = nil) do
    if Self.Match(R, Self.TransactionAt(I).InitialRequest) then
      Result := Self.TransactionAt(I)
    else Inc(I);    
end;

function TIdSipTransactionDispatcher.TransportAt(const Index: Integer): TIdSipAbstractTransport;
begin
  Result := Self.Transports[Index] as TIdSipAbstractTransport;
end;

//******************************************************************************
//* TIdSipMockTransactionDispatcher                                            *
//******************************************************************************
//* TIdSipMockTransactionDispatcher Public methods *****************************

constructor TIdSipMockTransactionDispatcher.Create;
begin
  inherited Create;

  Self.fTransport := TIdSipMockTransport.Create;
end;

destructor TIdSipMockTransactionDispatcher.Destroy;
begin
  Self.Transport.Free;

  inherited Destroy;
end;

procedure TIdSipMockTransactionDispatcher.SendRequest(const R: TIdSipRequest);
begin
  Self.Transport.SendRequest(R);
end;

procedure TIdSipMockTransactionDispatcher.SendResponse(const R: TIdSipResponse);
begin
  Self.Transport.SendResponse(R);
end;

//******************************************************************************
//* TIdSipTransaction                                                          *
//******************************************************************************
//* TIdSipTransaction Public methods *******************************************

class function TIdSipTransaction.GetTransactionType(const Request: TIdSipRequest): TIdSipTransactionClass;
begin
  if (Request.Method = MethodInvite) then
    Result := TIdSipClientInviteTransaction
  else
    Result := TIdSipClientNonInviteTransaction;
end;

constructor TIdSipTransaction.Create;
begin
  inherited Create;
end;

procedure TIdSipTransaction.HandleRequest(const R: TIdSipRequest);
begin
end;

procedure TIdSipTransaction.HandleResponse(const R: TIdSipResponse);
begin
end;

procedure TIdSipTransaction.Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                                       const InitialRequest: TIdSipRequest;
                                       const Timeout:        Cardinal = InitialT1_64);
begin
  Self.fDispatcher     := Dispatcher;
  Self.fInitialRequest := InitialRequest;
end;

//* TIdSipTransaction Protected methods ****************************************

procedure TIdSipTransaction.ChangeToCompleted(const R: TIdSipResponse);
begin
  Self.SetState(itsCompleted);
  Self.DoOnReceiveResponse(R);
end;

procedure TIdSipTransaction.ChangeToProceeding;
begin
  Self.SetState(itsProceeding);
end;

procedure TIdSipTransaction.ChangeToProceeding(const R: TIdSipRequest);
begin
  Self.ChangeToProceeding;
  Self.DoOnReceiveRequest(R);
end;

procedure TIdSipTransaction.ChangeToProceeding(const R: TIdSipResponse);
begin
  Self.ChangeToProceeding;
  Self.DoOnReceiveResponse(R);
end;

procedure TIdSipTransaction.ChangeToTerminated;
begin
  Self.SetState(itsTerminated);
  Self.DoOnTerminated;
end;

procedure TIdSipTransaction.DoOnFail(const Reason: String);
begin
  if Assigned(Self.OnFail) then
    Self.OnFail(Self, Reason);

  Self.ChangeToTerminated;
end;

procedure TIdSipTransaction.DoOnReceiveRequest(const R: TIdSipRequest);
begin
  if Assigned(Self.OnReceiveRequest) then
    Self.OnReceiveRequest(Self, R);
end;

procedure TIdSipTransaction.DoOnReceiveResponse(const R: TIdSipResponse);
begin
  if Assigned(Self.OnReceiveResponse) then
    Self.OnReceiveResponse(Self, R);
end;

procedure TIdSipTransaction.DoOnTerminated;
begin
  if Assigned(Self.OnTerminated) then
    Self.OnTerminated(Self);
end;

procedure TIdSipTransaction.SetState(const Value: TIdSipTransactionState);
begin
  fState := Value;
end;

procedure TIdSipTransaction.TryResendInitialRequest;
begin
  if not Self.Dispatcher.WillUseReliableTranport(Self.InitialRequest) then
    Self.TrySendRequest(Self.InitialRequest);
end;

procedure TIdSipTransaction.TrySendRequest(const R: TIdSipRequest);
begin
  try
    Self.Dispatcher.SendRequest(R);
  except
    on E: EIdException do
      Self.DoOnFail(E.Message);
  end;
end;

procedure TIdSipTransaction.TrySendResponse(const R: TIdSipResponse);
begin
  try
    Self.Dispatcher.SendResponse(R);
  except
    on E: EIdException do
      Self.DoOnFail(E.Message);
  end;
end;

//******************************************************************************
//* TIdSipClientInviteTransaction                                              *
//******************************************************************************
//* TIdSipClientInviteTransaction Public methods *******************************

constructor TIdSipClientInviteTransaction.Create;
begin
  inherited Create;

  Self.TimerA          := TIdSipTimer.Create(true);
  Self.TimerA.Interval := InitialT1;
  Self.TimerA.OnTimer  := Self.OnTimerA;

  Self.TimerB          := TIdSipTimer.Create(true);
  Self.TimerB.OnTimer  := Self.OnTimerB;

  Self.TimerD          := TIdSipTimer.Create(true);
  Self.TimerD.OnTimer  := Self.OnTimerD;
end;

destructor TIdSipClientInviteTransaction.Destroy;
begin
  Self.TimerD.TerminateAndWaitFor;
  Self.TimerD.Free;
  Self.TimerB.TerminateAndWaitFor;
  Self.TimerB.Free;
  Self.TimerA.TerminateAndWaitFor;
  Self.TimerA.Free;

  inherited Destroy;
end;

procedure TIdSipClientInviteTransaction.HandleResponse(const R: TIdSipResponse);
begin
  case Self.State of
    itsCalling: begin
      case R.StatusCode div 100 of
        1: Self.ChangeToProceeding(R);
        2: Self.ChangeToTerminated;
      else
        Self.ChangeToCompleted(R);
      end;
    end;

    itsProceeding: begin
      case R.StatusCode div 100 of
        1: Self.ChangeToProceeding(R);
        2: Self.ChangeToTerminated;
      else
        Self.ChangeToCompleted(R);
      end;
    end;

    itsCompleted: begin
      if ((R.StatusCode div 100) in [3..6]) then
        Self.ChangeToCompleted(R);
    end;
  end;
end;

procedure TIdSipClientInviteTransaction.Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                                                   const InitialRequest: TIdSipRequest;
                                                   const Timeout:        Cardinal = InitialT1_64);
begin
  inherited Initialise(Dispatcher, InitialRequest, Timeout);

  Self.ChangeToCalling;

  Self.TimerB.Interval := Timeout;
  Self.TimerD.Interval := Timeout;

  Self.TrySendRequest(Self.InitialRequest);

  Self.TimerA.Start;
  Self.TimerB.Start;
end;

//* TIdSipClientInviteTransaction Protected methods ****************************

procedure TIdSipClientInviteTransaction.ChangeToCompleted(const R: TIdSipResponse);
begin
  // It's unfortunate that we can't simply call inherited.
  // However, TrySendACK must be called before DoOnReceiveResponse,
  // and we have to set Self.State to itsCompleted before
  // TrySendACK because a transport failure changes Self.State
  // to itsTerminated.

  Self.TimerB.Stop;
  Self.TimerD.Start;

  Self.SetState(itsCompleted);
  Self.TrySendACK(R);
  Self.DoOnReceiveResponse(R);
end;

procedure TIdSipClientInviteTransaction.ChangeToTerminated;
begin
  inherited ChangeToTerminated;

  Self.TimerA.Stop;
end;

//* TIdSipClientInviteTransaction Private methods ******************************

procedure TIdSipClientInviteTransaction.ChangeToCalling;
begin
  Self.SetState(itsCalling);
end;

procedure TIdSipClientInviteTransaction.ChangeToProceeding(const R: TIdSipResponse);
begin
  inherited ChangeToProceeding(R);

  Self.TimerA.Stop;
  Self.TimerB.Stop;
end;

procedure TIdSipClientInviteTransaction.GenerateACK(const R:   TIdSipResponse;
                                                          Req: TIdSipRequest);
var
  Routes: TIdSipHeadersFilter;
begin
  Req.Method          := MethodAck;
  Req.RequestUri      := Self.InitialRequest.RequestUri;
  Req.SIPVersion      := Self.InitialRequest.SIPVersion;
  Req.CallID          := Self.InitialRequest.CallID;
  Req.From            := Self.InitialRequest.From;
  Req.ToHeader        := R.ToHeader;
  Req.Path.Add(Self.InitialRequest.Path.LastHop);
  Req.CSeq.SequenceNo := Self.InitialRequest.CSeq.SequenceNo;
  Req.CSeq.Method     := MethodAck;
  Req.ContentLength   := 0;
  Req.Body            := '';

  Routes := TIdSipHeadersFilter.Create(R.Headers, RouteHeader);
  try
    Req.Headers.Add(Routes);
  finally
    Routes.Free;
  end;
end;

procedure TIdSipClientInviteTransaction.OnTimerA(Sender: TObject);
begin
  Self.TimerA.Interval := Self.TimerA.Interval*2;
  Self.TryResendInitialRequest;
end;

procedure TIdSipClientInviteTransaction.OnTimerB(Sender: TObject);
begin
  Self.DoOnFail(SessionTimeoutMsg);
  Self.ChangeToTerminated;
  Self.TimerB.Stop;
end;

procedure TIdSipClientInviteTransaction.OnTimerD(Sender: TObject);
begin
  Self.ChangeToTerminated;
end;

procedure TIdSipClientInviteTransaction.TrySendACK(const R: TIdSipResponse);
var
  Ack: TIdSipRequest;
begin
  Ack := TIdSipRequest.Create;
  try
    Self.GenerateACK(R, Ack);
    Self.TrySendRequest(Ack);
  finally
    Ack.Free;
  end;
end;

//******************************************************************************
//* TIdSipServerInviteTransaction                                              *
//******************************************************************************
//* TIdSipServerInviteTransaction Public methods *******************************

constructor TIdSipServerInviteTransaction.Create;
begin
  inherited Create;

  Self.TimerG := TIdSipTimer.Create;
  Self.TimerG.Interval := InitialT1;
  Self.TimerG.OnTimer  := Self.OnTimerG;

  Self.TimerH := TIdSipTimer.Create;
  Self.TimerH.Interval := 64*InitialT1;
  Self.TimerH.OnTimer  := Self.OnTimerH;

  Self.TimerI := TIdSipTimer.Create;
  Self.TimerI.Interval := T4;
  Self.TimerI.OnTimer  := Self.OnTimerI;
end;

destructor TIdSipServerInviteTransaction.Destroy;
begin
  Self.TimerI.TerminateAndWaitFor;
  Self.TimerI.Free;
  Self.TimerH.TerminateAndWaitFor;
  Self.TimerH.Free;
  Self.TimerG.TerminateAndWaitFor;
  Self.TimerG.Free;

  inherited Destroy;
end;

procedure TIdSipServerInviteTransaction.HandleRequest(const R: TIdSipRequest);
begin
  case Self.State of
    itsProceeding: Self.TrySendLastResponse(R);
    itsCompleted: begin
      if (R.Method = MethodInvite) then
        Self.TrySendLastResponse(R)
      else if (R.Method = MethodAck) then
        Self.ChangeToConfirmed(R);
    end;
  end;
end;

procedure TIdSipServerInviteTransaction.HandleResponse(const R: TIdSipResponse);
begin
  Self.TrySendResponse(R);
  if (Self.State = itsProceeding) then begin
    case (R.StatusCode div 100) of
      1:    Self.ChangeToProceeding;
      2:    Self.ChangeToTerminated;
      3..6: Self.ChangeToCompleted(R);
    end;
  end;
end;

procedure TIdSipServerInviteTransaction.Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                                                   const InitialRequest: TIdSipRequest;
                                                   const Timeout:        Cardinal = InitialT1_64);
begin
  inherited Initialise(Dispatcher, InitialRequest, Timeout);

//  Self.ChangeToProceeding(Self.InitialRequest);
  Self.SetState(itsProceeding);
  Self.DoOnReceiveRequest(Self.InitialRequest);

  Self.TimerH.Interval := Timeout;

  Self.LastProceedingResponseSent := SIPTrying;
  Self.TrySend100Response(Self.InitialRequest);
end;

//* TIdSipServerInviteTransaction Protected methods ***************************

procedure TIdSipServerInviteTransaction.ChangeToCompleted(const R: TIdSipResponse);
begin
  inherited ChangeToCompleted(R);

  Self.TimerG.Start;
  Self.TimerH.Start;
end;

procedure TIdSipServerInviteTransaction.ChangeToProceeding(const R: TIdSipRequest);
begin
  Self.ChangeToProceeding;
  Self.DoOnReceiveRequest(R)
end;

procedure TIdSipServerInviteTransaction.ChangeToTerminated;
begin
  inherited ChangeToTerminated;

  Self.TimerH.Stop;
  Self.TimerI.Stop;
end;

//* TIdSipServerInviteTransaction Private methods ******************************

procedure TIdSipServerInviteTransaction.ChangeToConfirmed(const R: TIdSipRequest);
begin
  Self.SetState(itsConfirmed);
  Self.DoOnReceiveRequest(R);

  Self.TimerG.Stop;
  Self.TimerH.Stop;
  Self.TimerI.Start;
end;

procedure TIdSipServerInviteTransaction.Generate100(const R:   TIdSipRequest;
                                                          Res: TIdSipResponse);
begin
  Self.GenerateResponse(R, Res, SIPTrying);
end;

procedure TIdSipServerInviteTransaction.GenerateResponse(const R:          TIdSipRequest;
                                                               Res:        TIdSipResponse;
                                                         const StatusCode: Cardinal);
var
  TimestampHeaders: TIdSipHeadersFilter;
begin
  Res.StatusCode := StatusCode;
  Res.SIPVersion := SIPVersion;

  Res.From     := R.From;
  Res.ToHeader := R.ToHeader;
  Res.CallID   := R.CallID;
  Res.CSeq     := R.CSeq;

  TimestampHeaders := TIdSipHeadersFilter.Create(R.Headers, TimestampHeader);
  try
    Res.Headers.Add(TimestampHeaders);
  finally
    TimestampHeaders.Free;
  end;

  Res.Path.Add(Self.InitialRequest.Path.LastHop);
end;

procedure TIdSipServerInviteTransaction.OnTimerG(Sender: TObject);
begin
  if Self.TimerGHasFired then begin
    Self.TimerG.Interval := 2*Self.TimerG.Interval;

    if (Self.TimerG.Interval > T2) then
      Self.TimerG.Interval := T2;

  end
  else begin
    Self.TimerG.Interval := Min(2*Self.TimerG.Interval, T2);
    Self.TimerGHasFired := true;
  end;

  if not Self.Dispatcher.WillUseReliableTranport(Self.InitialRequest) then
    Self.TrySendLastResponse(Self.InitialRequest);
end;

procedure TIdSipServerInviteTransaction.OnTimerH(Sender: TObject);
begin
  Self.DoOnFail(SessionTimeoutMsg);
  Self.ChangeToTerminated;
end;

procedure TIdSipServerInviteTransaction.OnTimerI(Sender: TObject);
begin
  Self.ChangeToTerminated;
end;

procedure TIdSipServerInviteTransaction.TrySend100Response(const R: TIdSipRequest);
var
  Response: TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Self.Generate100(Self.InitialRequest, Response);

    Self.TrySendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure TIdSipServerInviteTransaction.TrySendLastResponse(const R: TIdSipRequest);
var
  Response: TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Self.GenerateResponse(R, Response, Self.LastProceedingResponseSent);
    Self.TrySendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure TIdSipServerInviteTransaction.TrySendResponse(const R: TIdSipResponse);
begin
  Self.LastProceedingResponseSent := R.StatusCode;

  inherited TrySendResponse(R);
end;

//******************************************************************************
//* TIdSipClientNonInviteTransaction                                           *
//******************************************************************************
//* TIdSipClientNonInviteTransaction Public methods ****************************

constructor TIdSipClientNonInviteTransaction.Create;
begin
  inherited Create;

  Self.TimerE          := TIdSipTimer.Create(true);
  Self.TimerE.Interval := InitialT1;
  Self.TimerE.OnTimer  := Self.OnTimerE;

  Self.TimerF          := TIdSipTimer.Create(true);
  Self.TimerF.OnTimer  := Self.OnTimerF;

  Self.TimerK          := TIdSipTimer.Create(true);
  Self.TimerK.Interval := T4;
  Self.TimerK.OnTimer  := Self.OnTimerK;
end;

destructor TIdSipClientNonInviteTransaction.Destroy;
begin
  Self.TimerK.TerminateAndWaitFor;
  Self.TimerK.Free;
  Self.TimerF.TerminateAndWaitFor;
  Self.TimerF.Free;
  Self.TimerE.TerminateAndWaitFor;
  Self.TimerE.Free;

  inherited Destroy;
end;

procedure TIdSipClientNonInviteTransaction.HandleResponse(const R: TIdSipResponse);
begin
  case Self.State of
    itsTrying: begin
      if R.IsFinal then
        Self.ChangeToCompleted(R)
      else
        Self.ChangeToProceeding(R);
    end;
    itsProceeding: begin
      if R.IsFinal then
        Self.ChangeToCompleted(R)
      else
        Self.ChangeToProceeding(R);
    end;
  end;
end;

procedure TIdSipClientNonInviteTransaction.Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                                                      const InitialRequest: TIdSipRequest;
                                                      const Timeout:        Cardinal = InitialT1_64);
begin
  inherited Initialise(Dispatcher, InitialRequest, Timeout);

  Self.ChangeToTrying;

  Self.TimerF.Interval := Timeout;

  Self.TrySendRequest(Self.InitialRequest);
  Self.TimerE.Start;
  Self.TimerF.Start;
end;

//* TIdSipClientNonInviteTransaction Protected methods *************************

procedure TIdSipClientNonInviteTransaction.ChangeToCompleted(const R: TIdSipResponse);
begin
  inherited ChangeToCompleted(R);

  Self.TimerE.Stop;
  Self.TimerF.Stop;
  Self.TimerK.Start;
end;

procedure TIdSipClientNonInviteTransaction.ChangeToProceeding(const R: TIdSipResponse);
begin
  inherited ChangeToProceeding(R);

  Self.TimerE.Interval := T2;
end;

procedure TIdSipClientNonInviteTransaction.ChangeToTrying;
begin
  Self.SetState(itsTrying);
end;

//* TIdSipClientNonInviteTransaction Private methods ***************************

procedure TIdSipClientNonInviteTransaction.OnTimerE(Sender: TObject);
begin
  if (Self.State = itsTrying) then begin
    Self.TimerE.Interval := 2*Self.TimerE.Interval;

    if (Self.TimerE.Interval > T2) then
      Self.TimerE.Interval := T2;
  end;

  Self.TryResendInitialRequest;
end;

procedure TIdSipClientNonInviteTransaction.OnTimerF(Sender: TObject);
begin
  Self.DoOnFail(SessionTimeoutMsg);
end;

procedure TIdSipClientNonInviteTransaction.OnTimerK(Sender: TObject);
begin
  Self.ChangeToTerminated;
end;

//******************************************************************************
//* TIdSipServerNonInviteTransaction                                           *
//******************************************************************************
//* TIdSipServerNonInviteTransaction Public methods ****************************

constructor TIdSipServerNonInviteTransaction.Create;
begin
  inherited Create;

  Self.TimerJ         := TIdSipTimer.Create(true);
  Self.TimerJ.OnTimer := Self.OnTimerJ;
end;

destructor TIdSipServerNonInviteTransaction.Destroy;
begin
  Self.TimerJ.TerminateAndWaitFor;
  Self.TimerJ.Free;

  inherited Destroy;
end;

procedure TIdSipServerNonInviteTransaction.HandleRequest(const R: TIdSipRequest);
begin
  case Self.State of
    itsCompleted, itsProceeding: begin
      Self.TrySendLastResponse(R);
    end;
  else
    raise Exception.Create('unhandled Self.State in ' + Self.ClassName + '.HandleRequest');
  end;
end;

procedure TIdSipServerNonInviteTransaction.HandleResponse(const R: TIdSipResponse);
begin
  case Self.State of
    itsTrying, itsProceeding: begin
      if R.IsFinal then
        Self.ChangeToCompleted(R)
      else
        Self.ChangeToProceeding(R);
    end;
  end;
end;

procedure TIdSipServerNonInviteTransaction.Initialise(const Dispatcher:     TIdSipTransactionDispatcher;
                                                      const InitialRequest: TIdSipRequest;
                                                      const Timeout:        Cardinal = InitialT1_64);
begin
  inherited Initialise(Dispatcher, InitialRequest, Timeout);

  Self.TimerJ.Interval := Timeout;

  Self.LastProceedingResponseSent := SIPTrying;  

  Self.ChangeToTrying(Self.InitialRequest);
end;

//* TIdSipServerNonInviteTransaction Protected methods *************************

procedure TIdSipServerNonInviteTransaction.ChangeToCompleted(const R: TIdSipResponse);
begin
  inherited ChangeToCompleted(R);

  Self.TrySendResponse(R);
  Self.TimerJ.Start;
end;

procedure TIdSipServerNonInviteTransaction.ChangeToProceeding(const R: TIdSipResponse);
begin
  inherited ChangeToProceeding(R);

  Self.TrySendResponse(R);
end;

procedure TIdSipServerNonInviteTransaction.TrySendResponse(const R: TIdSipResponse);
begin
  Self.LastProceedingResponseSent := R.StatusCode;

  inherited TrySendResponse(R);
end;

//* TIdSipServerNonInviteTransaction Private methods ***************************

procedure TIdSipServerNonInviteTransaction.ChangeToTrying(const R: TIdSipRequest);
begin
  Self.SetState(itsTrying);

  Self.DoOnReceiveRequest(R);
end;

procedure TIdSipServerNonInviteTransaction.GenerateResponse(const R:          TIdSipRequest;
                                                                  Res:        TIdSipResponse;
                                                            const StatusCode: Cardinal);
var
  TimestampHeaders: TIdSipHeadersFilter;
begin
  Res.StatusCode := StatusCode;
  Res.SIPVersion := SIPVersion;

  Res.From     := R.From;
  Res.ToHeader := R.ToHeader;
  Res.CallID   := R.CallID;
  Res.CSeq     := R.CSeq;

  TimestampHeaders := TIdSipHeadersFilter.Create(R.Headers, TimestampHeader);
  try
    Res.Headers.Add(TimestampHeaders);
  finally
    TimestampHeaders.Free;
  end;

  Res.Path.Add(Self.InitialRequest.Path.LastHop);
end;

procedure TIdSipServerNonInviteTransaction.OnTimerJ(Sender: TObject);
begin
  Self.ChangeToTerminated;
end;

procedure TIdSipServerNonInviteTransaction.TrySendLastResponse(const R: TIdSipRequest);
var
  Response: TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Self.GenerateResponse(R, Response, Self.LastProceedingResponseSent);
    Self.TrySendResponse(Response);
  finally
    Response.Free;
  end;
end;

end.
