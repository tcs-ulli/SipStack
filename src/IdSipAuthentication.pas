{
  (c) 2004 Directorate of New Technologies, Royal National Institute for Deaf people (RNID)

  The RNID licence covers this unit. Read the licence at:
      http://www.ictrnid.org.uk/docs/gw/rnid_license.txt

  This unit contains code written by:
    * Frank Shearar
}
unit IdSipAuthentication;

interface

uses
  Contnrs, IdHashMessageDigest, IdSipMessage, SysUtils;

type
  TIdUserInfo = class(TObject)
  private
    fDigest:   String;
    fRealm:    String;
    fUsername: String;
  public
    property Digest:   String read fDigest write fDigest;
    property Realm:    String read fRealm write fRealm;
    property Username: String read fUsername write fUsername;
  end;

  // I provide a means for Transaction User components (i.e., User Agent
  // cores, Proxy cores, Registrar cores and the like) to authenticate a
  // request. I do this by something supplying me with a list of
  // username+realms and digests. I thus never see the unencrypted passwords.
  // I also supply a means to create the digests.
  //
  // I thus provide the server half of the authentication process.
  TIdSipUserList = class(TObject)
  private
    Coder:    TIdHashMessageDigest5;
    UserInfo: TObjectList;
  protected
    function HasUser(const Username: String;
                     const Realm: String): Boolean;
    function IndexOf(const Username: String;
                     const Realm: String): Integer;
    function InfoAt(Index: Integer): TIdUserInfo;
  public
    constructor Create; virtual;
    destructor  Destroy; override;

    procedure AddUser(const Username: String;
                      const Realm: String;
                      const Digest: String); virtual;
    function  DigestFor(const Username: String;
                        const Realm: String): String; virtual;
    function  Digest(const Username: String;
                     const Realm: String;
                     const Password: String): String;
    function  Usercount: Integer;
  end;

  TIdSipAbstractAuthenticator = class(TIdSipUserList)
  private
    fRealm: String;
  public
    function Authenticate(Request: TIdSipRequest): Boolean; virtual;

    property Realm: String read fRealm write fRealm;
  end;

  TIdSipAuthenticator = class(TIdSipAbstractAuthenticator)
  end;

  // I track the information a UAC needs to authenticate against a particular
  // realm.
  // I implement the (client-side) authentication scheme defined by RFC 2617.
  // Note that in order to create an authorization header, you need to give
  // me a password. I don't store this password anywhere, so any caching of
  // passwords is up to whoever uses me.
  TIdRealmInfo = class(TObject)
  private
    fDigestUri:  String;
    fDigest:     String;
    fNonce:      String;
    fNonceCount: Cardinal;
    fRealm:      String;
    fUsername:   String;

    procedure CalculateCredentials(Authorization: TIdSipAuthorizationHeader;
                                   Challenge: TIdSipAuthenticateHeader;
                                   Info: TIdSipAuthenticationInfoHeader;
                                   const Method: String;
                                   const Body: String;
                                   const Password: String);
    procedure IncNonceCount;
    procedure ResetNonceCount;
    procedure SetNonce(const Value: String);
  public
    function CreateAuthorization(Challenge: TIdSipResponse;
                                 const Method: String;
                                 const Body: String;
                                 const Password: String): TIdSipAuthorizationHeader;

    property DigestUri:  String   read fDigestUri write fDigestUri;
    property Digest:     String   read fDigest write fDigest;
    property Nonce:      String   read fNonce write SetNonce;
    property NonceCount: Cardinal read fNonceCount write fNonceCount;
    property Realm:      String   read fRealm write fRealm;
    property Username:   String   read fUsername write fUsername;
  end;

  TIdKeyRing = class(TObject)
  private
    List: TObjectList;

    function CredentialsAt(Index: Integer): TIdRealmInfo;
    function HasKey(const Realm, Target: String): Boolean;
  public
    constructor Create;
    destructor  Destroy; override;

    procedure AddKey(Challenge: TIdSipAuthenticateHeader;
                     const Target: String;
                     const Username: String);
    function  Find(const Realm, Target: String): TIdRealmInfo;
    function  KeyCount: Integer;
  end;

  EAuthenticate = class(Exception);
  EAuthenticateClass = class of EAuthenticate;

  TIdSipMockAuthenticator = class(TIdSipAuthenticator)
  private
    fAuthenticateAllRequests: Boolean;
    fFailWith:                EAuthenticateClass;
  public
    function Authenticate(Request: TIdSipRequest): Boolean; override;

    property AuthenticateAllRequests: Boolean            read fAuthenticateAllRequests write fAuthenticateAllRequests;
    property FailWith:                EAuthenticateClass read fFailWith write fFailWith;
  end;

type
  TIdAlgorithmFunction = function(Auth: TIdSipAuthorizationHeader;
                                  const Password: String): String;
  TIdHashFunction = function(const S: String): String;
  TIdQopFunction = function(Auth: TIdSipAuthorizationHeader;
                            const Method: String;
                            const Body: String): String;
  TIdRequestDigestFunction = function(const A1: String;
                                      const A2: String;
                                      Auth: TIdSipAuthorizationHeader): String;

function  A1For(const Algorithm: String): TIdAlgorithmFunction;
function  A2For(const QopType: String): TIdQopFunction;
function  AlgorithmNotSpecifiedA1(Auth: TIdSipAuthorizationHeader;
                                  const Password: String): String;
function  HashFor(const AlgorithmName: String): TIdHashFunction;
function  KD(const Secret, Data: String; HashFunc: TIdHashFunction): String;
function  MD5(const S: String): String;
function  MD5A1(Auth: TIdSipAuthorizationHeader;
                const Password: String): String;
function  MD5SessionA1(Auth: TIdSipAuthorizationHeader;
                       const Password: String): String;
function  QopAuthA2(Auth: TIdSipAuthorizationHeader;
                    const Method: String;
                    const Body: String): String;
function  QopAuthIntA2(Auth: TIdSipAuthorizationHeader;
                       const Method: String;
                       const Body: String): String;
function  QopAuthRequestDigest(const A1: String;
                               const A2: String;
                               Auth: TIdSipAuthorizationHeader): String;
function  QopAuthIntRequestDigest(const A1: String;
                                  const A2: String;
                                  Auth: TIdSipAuthorizationHeader): String;
function  QopNotSpecifiedA2(Auth: TIdSipAuthorizationHeader;
                            const Method: String;
                            const Body: String): String;
function  QopNotSpecifiedRequestDigest(const A1: String;
                                       const A2: String;
                                       Auth: TIdSipAuthorizationHeader): String;
procedure RegisterAlgorithm(const Name: String; Func: TIdAlgorithmFunction);
procedure RegisterHash(const Name: String; Func: TIdHashFunction);
procedure RegisterQop(const Name: String; Func: TIdQopFunction);
procedure RegisterRequestDigest(const QopType: String; Func: TIdRequestDigestFunction);
function  RequestDigestFor(const QopType: String): TIdRequestDigestFunction;

implementation

uses
  Classes, IdRandom;

var
  GAlgorithmFunctions:     TStrings;
  GHashFunctions:          TStrings;
  GQopFunctions:           TStrings;
  GRequestDigestFunctions: TStrings;

//*******************************************************************************
//* Unit functions & procedures                                                 *
//*******************************************************************************
//* Unit Private functions & procedures *****************************************

function FunctionAt(FuncList: TStrings;
                    const Name: String): Pointer;
var
  Index: Integer;
begin

  Index := FuncList.IndexOf(Lowercase(Name));

  if (Index >= 0) then
    Result := FuncList.Objects[Index]
  else
    Result := nil;
end;

procedure RegisterFunction(FuncList: TStrings;
                           const Name: String;
                           Func: Pointer);
begin
  FuncList.AddObject(Lowercase(Name), Func)
end;

//* Unit Public functions & procedures ******************************************

function A1For(const Algorithm: String): TIdAlgorithmFunction;
begin
  Result := TIdAlgorithmFunction(FunctionAt(GAlgorithmFunctions, Algorithm));
end;

function A2For(const QopType: String): TIdQopFunction;
begin
  Result := TIdQopFunction(FunctionAt(GQopFunctions, QopType));
end;

function AlgorithmNotSpecifiedA1(Auth: TIdSipAuthorizationHeader;
                                 const Password: String): String;
begin
  Result := MD5A1(Auth, Password);
end;

function HashFor(const AlgorithmName: String): TIdHashFunction;
begin
  Result := TIdHashFunction(FunctionAt(GHashFunctions, AlgorithmName));
end;

function KD(const Secret, Data: String; HashFunc: TIdHashFunction): String;
begin
  Result := HashFunc(Trim(Secret) + ':' + Trim(Data));
end;

function MD5(const S: String): String;
var
  MD5: TIdHashMessageDigest5;
begin
  MD5 := TIdHashMessageDigest5.Create;
  try
    Result := Lowercase(MD5.AsHex(MD5.HashValue(S)));
  finally
    MD5.Free;
  end;
end;

function MD5A1(Auth: TIdSipAuthorizationHeader;
               const Password: String): String;
begin
  Result := Auth.Username + ':' + Auth.Realm + ':' + Password;
end;

function MD5SessionA1(Auth: TIdSipAuthorizationHeader;
                      const Password: String): String;
begin
  Result := Auth.Username + ':' + Auth.Realm + ':' + Password
          + ':' + Auth.Nonce + ':' + Auth.CNonce;
end;

function QopAuthA2(Auth: TIdSipAuthorizationHeader;
                   const Method: String;
                   const Body: String): String;
begin
  Result := Method + ':' + Auth.DigestUri;
end;

function QopAuthIntA2(Auth: TIdSipAuthorizationHeader;
                      const Method: String;
                      const Body: String): String;
var
  H: TIdHashFunction;
begin
  H := HashFor(Auth.Algorithm);

  Result := Method + ':'
          + Auth.DigestUri + ':'
          + H(Body);
end;

function QopAuthRequestDigest(const A1: String;
                              const A2: String;
                              Auth: TIdSipAuthorizationHeader): String;
var
  H: TIdHashFunction;
begin
  H := HashFor(Auth.Algorithm);

  Result := KD(H(A1),
               Auth.Nonce + ':'
             + Auth.NC + ':'
             + Auth.CNonce + ':'
             + Auth.Qop + ':'
             + H(A2),
               H);
end;

function QopAuthIntRequestDigest(const A1: String;
                                 const A2: String;
                                 Auth: TIdSipAuthorizationHeader): String;
begin
  Result := QopAuthRequestDigest(A1, A2, Auth);
end;

function QopNotSpecifiedA2(Auth: TIdSipAuthorizationHeader;
                           const Method: String;
                           const Body: String): String;
begin
  Result := QopAuthA2(Auth, Method, Body);
end;

function QopNotSpecifiedRequestDigest(const A1: String;
                                      const A2: String;
                                      Auth: TIdSipAuthorizationHeader): String;
var
  H: TIdHashFunction;
begin
  H := HashFor(Auth.Algorithm);

  Result := KD(H(A1),
               Auth.Nonce + ':'
             + H(A2),
               H);
end;

procedure RegisterAlgorithm(const Name: String; Func: TIdAlgorithmFunction);
begin
  RegisterFunction(GAlgorithmFunctions, Name, @Func);
end;

procedure RegisterHash(const Name: String; Func: TIdHashFunction);
begin
  RegisterFunction(GHashFunctions, Name, @Func);
end;

procedure RegisterQop(const Name: String; Func: TIdQopFunction);
begin
  RegisterFunction(GQopFunctions, Name, @Func);
end;

procedure RegisterRequestDigest(const QopType: String; Func: TIdRequestDigestFunction);
begin
  RegisterFunction(GRequestDigestFunctions, QopType, @Func);
end;

function RequestDigestFor(const QopType: String): TIdRequestDigestFunction;
begin
  Result := TIdRequestDigestFunction(FunctionAt(GRequestDigestFunctions, QopType));
end;

//*******************************************************************************
//* TIdSipUserList                                                              *
//*******************************************************************************
//* TIdSipUserList Public methods ***********************************************

constructor TIdSipUserList.Create;
begin
  inherited Create;

  Self.Coder    := TIdHashMessageDigest5.Create;
  Self.UserInfo := TObjectList.Create;
end;

destructor TIdSipUserList.Destroy;
begin
  Self.UserInfo.Free;
  Self.Coder.Free;

  inherited Destroy;
end;

procedure TIdSipUserList.AddUser(const Username: String;
                                 const Realm: String;
                                 const Digest: String);
var
  NewInfo: TIdUserInfo;
begin
  if Self.HasUser(Username, Realm) then begin
    Self.InfoAt(Self.IndexOf(Username, Realm)).Digest := Digest;
  end
  else begin
    NewInfo := TIdUserInfo.Create;
    try
      NewInfo.Username := Username;
      NewInfo.Realm    := Realm;
      NewInfo.Digest   := Digest;

      Self.UserInfo.Add(NewInfo);
    except
      if (Self.UserInfo.IndexOf(NewInfo) <> -1) then
        Self.UserInfo.Remove(NewInfo)
      else
        NewInfo.Free;
    end;
  end;
end;

function TIdSipUserList.Digest(const Username: String;
                               const Realm: String;
                               const Password: String): String;
begin
  Result := Self.Coder.AsHex(Self.Coder.HashValue(Username + ':' +
                                                  Realm + ':' +
                                                  Password));
  Result := Lowercase(Result);
end;

function TIdSipUserList.DigestFor(const Username: String;
                                  const Realm: String): String;
begin
  if Self.HasUser(Username, Realm) then
    Result := Self.InfoAt(Self.IndexOf(Username, Realm)).Digest
  else
    Result := '';
end;

function TIdSipUserList.Usercount: Integer;
begin
  Result := Self.UserInfo.Count;
end;

//* TIdSipUserList Private methods *********************************************

function TIdSipUserList.HasUser(const Username: String;
                                const Realm: String): Boolean;
begin
  Result := Self.IndexOf(Username, Realm) <> -1;
end;

function TIdSipUserList.IndexOf(const Username: String;
                                const Realm: String): Integer;
begin
  Result := 0;
  while (Result < Self.UserInfo.Count)
    and (Self.InfoAt(Result).Username <> Username)
    and (Self.InfoAt(Result).Realm <> Realm) do Inc(Result);

  if (Result = Self.UserInfo.Count) then
    Result := -1;
end;

function TIdSipUserList.InfoAt(Index: Integer): TIdUserInfo;
begin
  Result := Self.UserInfo[Index] as TIdUserInfo;
end;

//*******************************************************************************
//* TIdSipAbstractAuthenticator                                                 *
//*******************************************************************************
//* TIdSipAbstractAuthenticator Public methods **********************************

function TIdSipAbstractAuthenticator.Authenticate(Request: TIdSipRequest): Boolean;
var
  Auth: TIdSipAuthorizationHeader;
begin
{
     In this document the string obtained by applying the digest
     algorithm to the data "data" with secret "secret" will be denoted
     by KD(secret, data), and the string obtained by applying the
     checksum algorithm to the data "data" will be denoted H(data). The
     notation unq(X) means the value of the quoted-string X without the
     surrounding quotes.

     For the "MD5" and "MD5-sess" algorithms

         H(data) = MD5(data)

     and

         KD(secret, data) = H(concat(secret, ":", data))

     i.e., the digest is the MD5 of the secret concatenated with a colon
     concatenated with the data. The "MD5-sess" algorithm is intended to
     allow efficient 3rd party authentication servers; for the
     difference in usage, see the description in section 3.2.2.2.
}

  if Request.HasAuthorizationFor(Self.Realm) then begin
    Auth := Request.AuthorizationFor(Self.Realm);
    Result := Auth.Response = Self.DigestFor(Auth.Username, Auth.Realm);
  end
  else if Request.HasProxyAuthorizationFor(Self.Realm) then begin
    Result := false;
  end
  else
    Result := false;

  // TODO: This has to be clever enough to support both Proxy-Auth and WWW-Auth
end;

//*******************************************************************************
//* TIdRealmInfo                                                                *
//*******************************************************************************
//* TIdRealmInfo Public methods *************************************************

function TIdRealmInfo.CreateAuthorization(Challenge: TIdSipResponse;
                                          const Method: String;
                                          const Body: String;
                                          const Password: String): TIdSipAuthorizationHeader;
var
  ChallengeHeader: TIdSipAuthenticateHeader;
  InfoHeader:      TIdSipAuthenticationInfoHeader;
begin
  Assert(Challenge.HasWWWAuthenticate or Challenge.HasProxyAuthenticate,
         'You can''t generate an authorized request with no authentication request');

  if Challenge.HasWWWAuthenticate then
    ChallengeHeader := Challenge.FirstWWWAuthenticate
  else
    ChallengeHeader := Challenge.FirstProxyAuthenticate;

  Result := ChallengeHeader.CredentialHeaderType.Create;

  if Challenge.HasAuthenticationInfo then
    InfoHeader := Challenge.FirstAuthenticationInfo
  else
    InfoHeader := nil;

  Self.CalculateCredentials(Result,
                            ChallengeHeader,
                            InfoHeader,
                            Method,
                            Body,
                            Password);
end;

//* TIdRealmInfo Private methods ***********************************************

procedure TIdRealmInfo.CalculateCredentials(Authorization: TIdSipAuthorizationHeader;
                                            Challenge: TIdSipAuthenticateHeader;
                                            Info: TIdSipAuthenticationInfoHeader;
                                            const Method: String;
                                            const Body: String;
                                            const Password: String);
var
  DigestMaker: TIdRequestDigestFunction;
  QopData:     TIdQopFunction;
  UserData:    TIdAlgorithmFunction;
begin
  Self.IncNonceCount;

  Authorization.Assign(Challenge);

  Authorization.DigestUri := Self.DigestUri;
  Authorization.Nonce     := Self.Nonce;
  Authorization.Username  := Self.Username;

  DigestMaker := RequestDigestFor(Challenge.Qop);
  QopData     := A2For(Challenge.Qop);
  UserData    := A1For(Challenge.Algorithm);

  if (Challenge.Qop <> '') then begin
    Authorization.CNonce     := GRandomNumber.NextHexString;
    Authorization.NonceCount := Self.NonceCount;
  end;

  Authorization.Response := DigestMaker(UserData(Authorization, Password),
                                        QopData(Authorization, Method, Body),
                                        Authorization);

  if Assigned(Info) and Info.HasNextNonce then begin
    // Possibly authenticate the server
    Self.Nonce := Info.NextNonce;
  end;
end;

procedure TIdRealmInfo.IncNonceCount;
begin
  Inc(Self.fNonceCount);
end;

procedure TIdRealmInfo.ResetNonceCount;
begin
  Self.NonceCount := 0;
end;

procedure TIdRealmInfo.SetNonce(const Value: String);
begin
  Self.fNonce := Value;
  Self.ResetNonceCount;
end;

//*******************************************************************************
//* TIdKeyRing                                                                  *
//*******************************************************************************
//* TIdKeyRing Public methods ***************************************************

constructor TIdKeyRing.Create;
begin
  inherited Create;

  Self.List := TObjectList.Create(true);
end;

destructor TIdKeyRing.Destroy;
begin
  Self.List.Free;

  inherited Destroy;
end;

procedure TIdKeyRing.AddKey(Challenge: TIdSipAuthenticateHeader;
                            const Target: String;
                            const Username: String);
var
  NewInfo: TIdRealmInfo;
begin
  if not Self.HasKey(Challenge.Realm, Target) then begin
    NewInfo := TIdRealmInfo.Create;
    try
      Self.List.Add(NewInfo);

      NewInfo.DigestUri := Target;
      NewInfo.Nonce     := Challenge.Nonce;
      NewInfo.Realm     := Challenge.Realm;
      NewInfo.Username  := Username;
    except
      if (Self.List.IndexOf(NewInfo) <> -1) then
        Self.List.Remove(NewInfo)
      else
        NewInfo.Free;

      raise;
    end;
  end;
end;

function TIdKeyRing.Find(const Realm, Target: String): TIdRealmInfo;
var
  I: Integer;
begin
  Result := nil;

  I := 0;
  while (I < Self.List.Count) and not Assigned(Result) do begin
    if    (Self.CredentialsAt(I).DigestUri = Target)
      and (Self.CredentialsAt(I).Realm = Realm) then
      Result := Self.CredentialsAt(I);
    Inc(I);
  end;
end;

function TIdKeyRing.KeyCount: Integer;
begin
  Result := Self.List.Count;
end;

//* TIdKeyRing Private methods *************************************************

function TIdKeyRing.CredentialsAt(Index: Integer): TIdRealmInfo;
begin
  Result := Self.List[Index] as TIdRealmInfo;
end;

function TIdKeyRing.HasKey(const Realm, Target: String): Boolean;
begin
  Result := Assigned(Self.Find(Realm, Target));
end;

//*******************************************************************************
//* TIdSipMockAuthenticator                                                     *
//*******************************************************************************
//* TIdSipMockAuthenticator Public methods **************************************

function TIdSipMockAuthenticator.Authenticate(Request: TIdSipRequest): Boolean;
begin
  if (Self.FailWith <> nil) then
    raise Self.FailWith.Create('TIdSipMockAuthenticator.Authenticate');

  if Self.AuthenticateAllRequests then Result := true
  else
    Result := inherited Authenticate(Request);
end;

initialization
  GAlgorithmFunctions     := TStringList.Create;
  GHashFunctions          := TStringList.Create;
  GQopFunctions           := TStringList.Create;
  GRequestDigestFunctions := TStringList.Create;

  RegisterAlgorithm('',             AlgorithmNotSpecifiedA1);
  RegisterAlgorithm(MD5Name,        MD5A1);
  RegisterAlgorithm(MD5SessionName, MD5SessionA1);

  RegisterHash('',             MD5);
  RegisterHash(MD5Name,        MD5);
  RegisterHash(MD5SessionName, MD5);

  RegisterQop('',         QopNotSpecifiedA2);
  RegisterQop(QopAuth,    QopAuthA2);
  RegisterQop(QopAuthInt, QopAuthIntA2);

  RegisterRequestDigest('',         QopNotSpecifiedRequestDigest);
  RegisterRequestDigest(QopAuth,    QopAuthRequestDigest);
  RegisterRequestDigest(QopAuthInt, QopAuthIntRequestDigest);
finalization
  GRequestDigestFunctions.Free;
  GQopFunctions.Free;
  GHashFunctions.Free;
  GAlgorithmFunctions.Free;
end.
