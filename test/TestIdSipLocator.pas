{
  (c) 2004 Directorate of New Technologies, Royal National Institute for Deaf people (RNID)

  The RNID licence covers this unit. Read the licence at:
      http://www.ictrnid.org.uk/docs/gw/rnid_license.txt

  This unit contains code written by:
    * Frank Shearar
}
unit TestIdSipLocator;

interface

uses
  Classes, IdSipDns, IdSipLocator, IdSipMessage, IdSipMockLocator,
  TestFramework;

type
  TestTIdSipLocation = class(TTestCase)
  private
    Address:   String;
    Loc:       TIdSipLocation;
    Port:      Cardinal;
    Transport: String;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCopy;
    procedure TestCreate;
    procedure TestCreateFromVia;
  end;

  TestTIdSipLocations = class(TTestCase)
  private
    Locs: TIdSipLocations;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAddLocation;
    procedure TestAddLocationsFromNames;
    procedure TestCount;
    procedure TestIsEmpty;
  end;

  TestTIdSipAbstractLocator = class(TTestCase)
  private
    ARecord:        String;
    AAAARecord:     String;
    Domain:         String;
    IP:             String;
    Loc:            TIdSipMockLocator;
    NameRecs:       TIdDomainNameRecords;
    Naptr:          TIdNaptrRecords;
    Port:           Cardinal;
    Srv:            TIdSrvRecords;
    Target:         TIdSipUri;
    TransportParam: String;

    procedure AddNameRecords(const Domain: String);
  public
    procedure SetUp; override;
    procedure TearDown; override;

    procedure CheckAorAAAARecords(Locations: TIdSipLocations;
                                  const ExpectedTransport: String;
                                  const MsgPrefix: String);
  published
    procedure TestFindServersForResponseWithNameAndPort;
    procedure TestFindServersForResponseWithNameNoSrv;
    procedure TestFindServersForResponseWithNumericSentBy;
    procedure TestFindServersForResponseWithNumericSentByAndPort;
    procedure TestFindServersForResponseWithReceivedParam;
    procedure TestFindServersForResponseWithReceivedParamAndRport;
    procedure TestFindServersForResponseWithReceivedParamAndNumericSentBy;
    procedure TestFindServersForResponseWithReceivedParamAndIPv6NumericSentBy;
    procedure TestFindServersForResponseWithRport;
    procedure TestFindServersForResponseWithSrv;
    procedure TestNameAndPortWithTransportParam;
    procedure TestNameNoNaptrNoSrv;
    procedure TestNameNaptrSomeSrv;
    procedure TestNumericAddressNonStandardPort;
    procedure TestNumericAddressUsesUdp;
    procedure TestNumericAddressSipsUriUsesTls;
    procedure TestNumericAddressSipsUriNonStandardPort;
    procedure TestNumericMaddr;
    procedure TestNumericMaddrIPv6;
    procedure TestNumericMaddrSips;
    procedure TestNumericMaddrSipsIPv6;
    procedure TestSrvNoNameRecords;
    procedure TestSrvNotAvailable;
    procedure TestSrvTarget;
    procedure TestTransportParamTakesPrecedence;
    procedure TestTransportFor;
    procedure TestTransportForNameAndExplicitPort;
    procedure TestTransportForNumericIPv4;
    procedure TestTransportForNumericIPv6;
    procedure TestTransportForWithNaptr;
    procedure TestTransportForWithoutNaptrAndNoSrv;
    procedure TestTransportForWithoutNaptrWithSrv;
    procedure TestWithoutNaptrWithSrv;
    procedure TestFindServersForNameNaptrNoSrv;
    procedure TestFindServersForNameNaptrSrv;
    procedure TestFindServersForNameNoNaptrManualTransportNoSrv;
    procedure TestFindServersForNameNoNaptrManualTransportSrv;
    procedure TestFindServersForNameNoNaptrNoManualTransportNoSrv;
    procedure TestFindServersForNameNoNaptrNoManualTransportSrv;
    procedure TestFindServersForNameWithPort;
    procedure TestFindServersForNumericAddress;
    procedure TestFindServersForNumericAddressWithPort;
  end;

  TestTIdSipMockLocator = class(TTestCase)
  private
    AOR: TIdUri;
    Loc: TIdSipMockLocator;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLookupCount;
    procedure TestResolveNameRecords;
    procedure TestResolveNAPTRSip;
    procedure TestResolveNAPTRSips;
    procedure TestResolveSRV;
    procedure TestResolveSRVWithNameRecords;
  end;

implementation

uses
  IdSipConsts, IdSipTransport, Math, SysUtils;

function Suite: ITestSuite;
begin
  Result := TTestSuite.Create('IdSipLocator unit tests');
  Result.AddTest(TestTIdSipLocation.Suite);
  Result.AddTest(TestTIdSipLocations.Suite);
  Result.AddTest(TestTIdSipAbstractLocator.Suite);
  Result.AddTest(TestTIdSipMockLocator.Suite);
end;

//******************************************************************************
//* TestTIdSipLocation                                                         *
//******************************************************************************
//* TestTIdSipLocation Public methods ******************************************

procedure TestTIdSipLocation.SetUp;
begin
  inherited SetUp;

  Self.Address   := '127.0.0.1';
  Self.Port      := 9999;
  Self.Transport := TcpTransport;

  Self.Loc := TIdSipLocation.Create(Self.Transport, Self.Address, Self.Port);
end;

procedure TestTIdSipLocation.TearDown;
begin
  Self.Loc.Free;

  inherited TearDown;
end;

//* TestTIdSipLocation Published methods ***************************************

procedure TestTIdSipLocation.TestCopy;
var
  Copy: TIdSipLocation;
begin
  Copy := Self.Loc.Copy;
  try
    CheckEquals(Self.Loc.IPAddress, Copy.IPAddress, 'IPAddress');
    CheckEquals(Self.Loc.Port,      Copy.Port,      'Port');
    CheckEquals(Self.Loc.Transport, Copy.Transport, 'Transport');
  finally
    Copy.Free;
  end;
end;

procedure TestTIdSipLocation.TestCreate;
begin
  CheckEquals(Self.Address,   Self.Loc.IPAddress, 'IPAddress');
  CheckEquals(Self.Port,      Self.Loc.Port,      'Port');
  CheckEquals(Self.Transport, Self.Loc.Transport, 'Transport');
end;

procedure TestTIdSipLocation.TestCreateFromVia;
var
  Loc: TIdSipLocation;
  Via: TIdSipViaHeader;
begin
  Via := TIdSipViaHeader.Create;
  try
    Via.Port      := Self.Port;
    Via.SentBy    := Self.Address;
    Via.Transport := Self.Transport;

    Loc := TIdSipLocation.Create(Via);
    try
      CheckEquals(Via.Port,      Loc.Port,      'Port');
      CheckEquals(Via.SentBy,    Loc.IPAddress, 'IPAddress');
      CheckEquals(Via.Transport, Loc.Transport, 'Transport');
    finally
      Loc.Free;
    end;
  finally
    Via.Free;
  end;
end;

//******************************************************************************
//* TestTIdSipLocations                                                        *
//******************************************************************************
//* TestTIdSipLocations Public methods *****************************************

procedure TestTIdSipLocations.SetUp;
begin
  inherited SetUp;

  Self.Locs := TIdSipLocations.Create;
end;

procedure TestTIdSipLocations.TearDown;
begin
  Self.Locs.Free;

  inherited TearDown;
end;

//* TestTIdSipLocations Published methods **************************************

procedure TestTIdSipLocations.TestAddLocation;
const
  Transport = TcpTransport;
  Address   = 'foo.com';
  Port      = IdPORT_SIP;
begin
  Self.Locs.AddLocation(Transport, Address, Port);

  CheckEquals(Address,   Self.Locs.First.IPAddress, 'IPAddress');
  CheckEquals(Port,      Self.Locs.First.Port,      'Port');
  CheckEquals(Transport, Self.Locs.First.Transport, 'Transport');
end;

procedure TestTIdSipLocations.TestAddLocationsFromNames;
const
  Transport = TcpTransport;
  Port      = IdPORT_SIP;
var
  I:     Integer;
  Names: TIdDomainNameRecords;
begin
  Names := TIdDomainNameRecords.Create;
  try
    Names.Add(DnsAAAARecord, 'foo.com', '::1');
    Names.Add(DnsARecord,    'bar.com', '127.0.0.1');

    for I := 0 to Min(Names.Count, Self.Locs.Count) - 1 do begin
      CheckEquals(Transport,
                  Self.Locs[I].Transport,
                  IntToStr(I) + 'th location transport');
      CheckEquals(Names[I].IPAddress,
                  Self.Locs[I].IPAddress,
                  IntToStr(I) + 'th location address');
      CheckEquals(Port,
                  Self.Locs[I].Port,
                  IntToStr(I) + 'th location port');
    end;

    Self.Locs.AddLocationsFromNames(Transport, Port, Names);

    CheckEquals(Names.Count,
                Self.Locs.Count,
                'Number of records');
  finally
    Names.Free;
  end;
end;

procedure TestTIdSipLocations.TestCount;
var
  I: Integer;
begin
  CheckEquals(0, Self.Locs.Count, 'Empty list');

  for I := 1 to 5 do begin
    Self.Locs.AddLocation(TcpTransport, 'foo.com', I);
    CheckEquals(I,
                Self.Locs.Count,
                'Added ' + IntToStr(I) + ' item(s)');
  end;
end;

procedure TestTIdSipLocations.TestIsEmpty;
var
  I: Integer;
begin
  Check(Self.Locs.IsEmpty, 'Empty list');

  for I := 1 to 5 do begin
    Self.Locs.AddLocation(TcpTransport, 'foo.com', I);
    Check(not Self.Locs.IsEmpty,
          'IsEmpty after ' + IntToStr(I) + ' item(s)');
  end;
end;

//******************************************************************************
//* TestTIdSipAbstractLocator                                                  *
//******************************************************************************
//* TestTIdSipAbstractLocator Public methods ***********************************

procedure TestTIdSipAbstractLocator.SetUp;
begin
  inherited SetUp;

  Self.ARecord    := '127.0.0.1';
  Self.AAAARecord := '::1';
  Self.Domain     := 'foo.com';
  Self.IP         := '127.0.0.1';
  Self.Loc        := TIdSipMockLocator.Create;
  Self.NameRecs   := TIdDomainNameRecords.Create;
  Self.Naptr      := TIdNaptrRecords.Create;
  Self.Port       := IdPORT_SIP;
  Self.Srv        := TIdSrvRecords.Create;
  Self.Target     := TIdSipUri.Create;
end;

procedure TestTIdSipAbstractLocator.TearDown;
begin
  Self.Target.Free;
  Self.Srv.Free;
  Self.Naptr.Free;
  Self.NameRecs.Free;
  Self.Loc.Free;

  inherited Destroy;
end;

procedure TestTIdSipAbstractLocator.CheckAorAAAARecords(Locations: TIdSipLocations;
                                                        const ExpectedTransport: String;
                                                        const MsgPrefix: String);
begin
  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(Self.Loc.NameRecords.Count,
                Locations.Count, MsgPrefix + ': Location count');

    CheckEquals(ExpectedTransport,
                Locations[0].Transport,
                MsgPrefix + ': 1st record Transport');
    CheckEquals(Self.ARecord,
                Locations[0].IPAddress,
                MsgPrefix + ': 1st record IPAddress');
    CheckEquals(Self.Port,
                Locations[0].Port,
                MsgPrefix + ': 1st record Port');

    CheckEquals(ExpectedTransport,
                Locations[1].Transport,
                MsgPrefix + ': 2nd record Transport');
    CheckEquals(Self.AAAARecord,
                Locations[1].IPAddress,
                MsgPrefix + ': 2nd record IPAddress');
    CheckEquals(Self.Port,
                Locations[1].Port,
                MsgPrefix + ': 2nd record Port');
  finally
    Locations.Free;
  end;
end;

//* TestTIdSipAbstractLocator Private methods **********************************

procedure TestTIdSipAbstractLocator.AddNameRecords(const Domain: String);
begin
  Self.Loc.AddA(   Self.Domain, Self.ARecord);
  Self.Loc.AddAAAA(Self.Domain, Self.AAAARecord);
end;

//* TestTIdSipAbstractLocator Published methods ********************************

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithNameAndPort;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Self.Loc.AddAAAA(Self.Domain, Self.AAAARecord);
  Self.Loc.AddA(   Self.Domain, Self.ARecord);

  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP ' + Domain + ':6666';

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Self.Loc.NameRecords[0].IPAddress,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[0].Port,
                  'First location port');

      CheckEquals(Response.LastHop.Transport,
                  Locations[1].Transport,
                  'Second location transport');
      CheckEquals(Self.Loc.NameRecords[1].IPAddress,
                  Locations[1].IPAddress,
                  'Second location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[1].Port,
                  'Second location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithNameNoSrv;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Self.Loc.AddAAAA(Self.Domain, Self.AAAARecord);
  Self.Loc.AddA(   Self.Domain, Self.ARecord);

  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP ' + Domain;

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Self.Loc.NameRecords[0].IPAddress,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[0].Port,
                  'First location port');

      CheckEquals(Response.LastHop.Transport,
                  Locations[1].Transport,
                  'Second location transport');
      CheckEquals(Self.Loc.NameRecords[1].IPAddress,
                  Locations[1].IPAddress,
                  'Second location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[1].Port,
                  'Second location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithNumericSentBy;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP 127.0.0.1';

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Self.IP,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[0].Port,
                  'First location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithNumericSentByAndPort;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP 127.0.0.1:666';

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Self.IP,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[0].Port,
                  'First location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithReceivedParam;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP gw1.leo-ix.net;received=' + Self.IP;

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Response.LastHop.Received,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[0].Port,
                  'First location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithReceivedParamAndRport;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Self.Port := 6666;
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP gw1.leo-ix.net'
                                             + ';received=' + Self.IP
                                             + ';rport=' + IntToStr(Self.Port);

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Response.LastHop.Received,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Rport,
                  Locations[0].Port,
                  'First location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithReceivedParamAndNumericSentBy;
const
  SentByIP = '6.6.6.6';
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP ' + SentByIP + ';received=' + Self.IP;

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[1].Transport,
                  'First location transport');
      CheckEquals(SentByIP,
                  Locations[1].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[1].Port,
                  'First location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithReceivedParamAndIpv6NumericSentBy;
const
  SentByIP = '[2002:dead:beef:1::1]';
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP ' + SentByIP + ';received=' + Self.IP;

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[1].Transport,
                  'First location transport');
      CheckEquals(SentByIP,
                  Locations[1].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[1].Port,
                  'First location port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithRport;
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
begin
  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/UDP 127.0.0.1;rport=666';

    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(Response.LastHop.Transport,
                  Locations[0].Transport,
                  'First location transport');
      CheckEquals(Self.IP,
                  Locations[0].IPAddress,
                  'First location address');
      CheckEquals(Response.LastHop.Port,
                  Locations[0].Port,
                  'First location port: must ignore rport');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForResponseWithSrv;
const
  SecondRecord = '::2';
  ThirdRecord  = '::3';
var
  Locations: TIdSipLocations;
  Response:  TIdSipResponse;
  TlsDomain: String;
begin
  TlsDomain := 'sips.' + Self.Domain;

  Self.Loc.AddSRV(Self.Domain, SrvTlsPrefix, 0, 0, IdPORT_SIPS, TlsDomain);
  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix, 0, 0, IdPORT_SIP,  Self.Domain);

  Self.Loc.AddAAAA(Self.Domain, Self.AAAARecord);
  Self.Loc.AddAAAA(TlsDomain, SecondRecord);
  Self.Loc.AddAAAA(TlsDomain, ThirdRecord);

  Response := TIdSipResponse.Create;
  try
    Response.AddHeader(ViaHeaderFull).Value := 'SIP/2.0/TLS ' + Self.Domain;
    Locations := Self.Loc.FindServersFor(Response);
    try
      CheckEquals(2,
                  Locations.Count,
                  'Wrong number of records');

      CheckEquals(TlsTransport,
                  Locations[0].Transport,
                  '1st record transport');
      CheckEquals(SecondRecord,
                  Locations[0].IPAddress,
                  '1st record address');
      CheckEquals(IdPORT_SIPS,
                  Locations[0].Port,
                  '1st record port');
      CheckEquals(TlsTransport,
                  Locations[1].Transport,
                  '2nd record transport');
      CheckEquals(ThirdRecord,
                  Locations[1].IPAddress,
                  '2nd record address');
      CheckEquals(IdPORT_SIPS,
                  Locations[1].Port,
                  '2nd record port');
    finally
      Locations.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNameAndPortWithTransportParam;
var
  Locations: TIdSipLocations;
begin
  // Iterate over the SRV RRs for _sip._udp (despite the remote side preferring
  // TLS).
  Self.Target.Uri := 'sip:example.com;transport=udp';

  Self.Loc.AddNAPTR(Self.IP,  50, 50, 's', NaptrTlsService, '_sips._tcp.example.com');
  Self.Loc.AddNAPTR(Self.IP,  90, 50, 's', NaptrTcpService, '_sip._tcp.example.com');
  Self.Loc.AddNAPTR(Self.IP, 100, 50, 's', NaptrUdpService, '_sip._udp.example.com');
  Self.Loc.AddSRV('example.com', '_sips._tcp', 0, 0, 5061, 'paranoid.example.com');
  Self.Loc.AddSRV('example.com', '_sip._tcp', 0, 0, 5061,  'reliable.example.com');
  Self.Loc.AddSRV('example.com', '_sip._udp', 0, 0, 5061,  'unreliable.example.com');
  Self.Loc.AddA('paranoid.example.com',   '127.0.0.1');
  Self.Loc.AddA('reliable.example.com',   '127.0.0.2');
  Self.Loc.AddA('unreliable.example.com', '127.0.0.3');

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(1, Locations.Count, 'Number of locations');
    CheckEquals('127.0.0.3', Locations[0].IPAddress, 'Wrong location');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNameNoNaptrNoSrv;
var
  Locations: TIdSipLocations;
begin
  // Use all A/AAAA RRs for the host
  Self.Target.Uri := 'sip:' + Self.Domain;

  Self.AddNameRecords(Self.Target.Host);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Self.CheckAorAAAARecords(Locations, UdpTransport, 'No NAPTR no SRV');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNameNaptrSomeSrv;
var
  Locations: TIdSipLocations;
begin
  // Iterate over SRV records
  Self.Target.Uri := 'sip:' + Self.Domain;

  // We have two NAPTR records. Probably as a result of an admin slip-up,
  // there're no SRV records for the first NAPTR. This test shows that we look
  // up SRV stuff for NAPTR records at least until we find some SRVs.
  Self.Loc.AddNAPTR(Self.Domain, 0, 0, NaptrDefaultFlags, NaptrTlsService, SrvTlsPrefix + '.' + Self.Domain);
  Self.Loc.AddNAPTR(Self.Domain, 0, 0, NaptrDefaultFlags, NaptrTcpService, SrvTcpPrefix + '.' + Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix, 0, 0, IdPORT_SIP, 'sip.' + Self.Domain);
  Self.Loc.AddAAAA('sip.' + Self.Domain, Self.AAAARecord);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(Self.Loc.NameRecords.Count,
                Locations.Count,
                'No SRV lookup for NAPTR records beyond the first?');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericAddressNonStandardPort;
var
  Locations: TIdSipLocations;
begin
  Self.Port       := 3000;
  Self.Target.Uri := 'sip:' + Self.IP + ':' + IntToStr(Self.Port);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(UdpTransport, Locations.First.Transport, 'Transport');
    CheckEquals(Self.IP,      Locations.First.IPAddress, 'IPAddress');
    CheckEquals(Self.Port,    Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericAddressUsesUdp;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sip:' + Self.IP;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(UdpTransport, Locations.First.Transport, 'Transport');
    CheckEquals(Self.IP,      Locations.First.IPAddress, 'IPAddress');
    CheckEquals(Self.Port,    Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericAddressSipsUriUsesTls;
var
  Locations: TIdSipLocations;
begin
  Self.Port       := IdPORT_SIPS;
  Self.Target.Uri := 'sips:' + Self.IP;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(TlsTransport, Locations.First.Transport, 'Transport');
    CheckEquals(Self.IP,      Locations.First.IPAddress, 'IPAddress');
    CheckEquals(Self.Port,    Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericAddressSipsUriNonStandardPort;
var
  Locations: TIdSipLocations;
begin
  Self.Port       := 3000;
  Self.Target.Uri := 'sips:' + Self.IP + ':' + IntToStr(Self.Port);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(TlsTransport, Locations.First.Transport, 'Transport');
    CheckEquals(Self.IP,      Locations.First.IPAddress, 'IPAddress');
    CheckEquals(Self.Port,    Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericMaddr;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sip:foo.com;maddr=' + Self.IP;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(UdpTransport, Locations.First.Transport, 'Transport');
    CheckEquals(Self.IP,      Locations.First.IPAddress, 'IPAddress');
    CheckEquals(Self.Port,    Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericMaddrIPv6;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sip:foo.com;maddr=' + Self.AAAARecord;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(UdpTransport,    Locations.First.Transport, 'Transport');
    CheckEquals(Self.AAAARecord, Locations.First.IPAddress, 'IPAddress');
    CheckEquals(Self.Port,       Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericMaddrSips;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sips:foo.com;maddr=' + Self.ARecord;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(TlsTransport, Locations.First.Transport, 'Transport');
    CheckEquals(Self.ARecord, Locations.First.IPAddress, 'IPAddress');
    CheckEquals(IdPORT_SIPS,  Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestNumericMaddrSipsIPv6;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sips:foo.com;maddr=' + Self.AAAARecord;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(TlsTransport,    Locations.First.Transport, 'Transport');
    CheckEquals(Self.AAAARecord, Locations.First.IPAddress, 'IPAddress');
    CheckEquals(IdPORT_SIPS,     Locations.First.Port,      'Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestSrvNoNameRecords;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri :='sip:' + Self.Domain;

  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix,  0, 0, 0, Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvSctpPrefix, 0, 0, 0, Self.Domain);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.IsEmpty,
          'The locator added locations that don''t exist');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestSrvNotAvailable;
var
  Locations: TIdSipLocations;
begin
  // SRV targets can sometimes be '.' - the root name of all domain names.
  // We ignore them (they mean "we don't support the service you're looking
  // for"). Once we have the SRV records though we need A/AAAA records to
  // get the actual IP addresses we want to contact.

  Self.Target.Uri :='sip:' + Self.Domain;

  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix,  0, 0, 0, SrvNotAvailableTarget);
  Self.Loc.AddSRV(Self.Domain, SrvSctpPrefix, 0, 0, 0, Self.Domain);

  Self.Loc.AddA(Self.Domain, Self.ARecord);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(1,
                Locations.Count,
                'The locator didn''t filter out the "unavailable" SRV');
    CheckEquals(SctpTransport, Locations[0].Transport, 'Wrong location found');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestSrvTarget;
begin
  Self.Target.Uri := 'sip:' + Self.Domain;

  CheckEquals('_sip._tcp.' + Self.Domain,
              Self.Loc.SrvTarget(Self.Target, 'tcp'),
              'SIP/TCP lookup');

  CheckEquals('_sip._tcp.' + Self.Domain,
              Self.Loc.SrvTarget(Self.Target, 'TCP'),
              'Transports all lowercase');

  Self.Target.Scheme := SipsScheme;
  CheckEquals('_sips._tcp.' + Self.Domain,
              Self.Loc.SrvTarget(Self.Target, 'tls'),
              'SIP/TLS lookup');
end;

procedure TestTIdSipAbstractLocator.TestTransportParamTakesPrecedence;
var
  Locations: TIdSipLocations;
begin
  Self.TransportParam := TransportParamSCTP;
  Self.Target.Uri := 'sip:127.0.0.1;transport=' + Self.TransportParam;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 0, 'Too few locations');

    CheckEquals(ParamToTransport(Self.TransportParam),
                Locations.First.Transport,
                'Transport');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestTransportFor;
begin
  Self.TransportParam := TransportParamSCTP;
  Self.Target.Uri := 'sip:foo.com;transport=' + Self.TransportParam;

  CheckEquals(ParamToTransport(Self.TransportParam),
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'Transport parameter must take precedence');
end;

procedure TestTIdSipAbstractLocator.TestTransportForNameAndExplicitPort;
begin
  Self.Target.Uri := 'sip:' + Self.Domain + ':' + IntToStr(Self.Port);

  CheckEquals(UdpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Name, explicit port');

  Self.Target.Uri := 'sips:' + Self.Domain + ':' + IntToStr(Self.Port);

  CheckEquals(TlsTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Name, explicit port');
end;

procedure TestTIdSipAbstractLocator.TestTransportForNumericIPv4;
begin
  Self.Target.Uri := 'sip:' + Self.IP;

  CheckEquals(UdpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Numeric IPv4 address');

  Self.Target.Uri := 'sip:' + Self.IP + ':' + IntToStr(Self.Port);
  CheckEquals(UdpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Numeric IPv4 address, explicit port');

  Self.Target.Scheme := SipsScheme;
  CheckEquals(TlsTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Numeric IPv4 address');

  Self.Target.Uri := 'sips:' + Self.IP + ':' + IntToStr(Self.Port);
  CheckEquals(TlsTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Numeric IPv4 address, explicit port');
end;

procedure TestTIdSipAbstractLocator.TestTransportForNumericIPv6;
begin
  Self.IP := '[::1]';
  Self.Target.Uri := 'sip:' + Self.IP;

  CheckEquals(UdpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Numeric IPv6 address');

  Self.Target.Uri := 'sip:' + Self.IP + ':' + IntToStr(Self.Port);
  CheckEquals(UdpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Numeric IPv6 address, port');

  Self.Target.Scheme := SipsScheme;
  CheckEquals(TlsTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Numeric IPv6 address');

  Self.Target.Uri := 'sips:' + Self.IP + ':' + IntToStr(Self.Port);
  CheckEquals(TlsTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Numeric IPv6 address, explicit port');
end;

procedure TestTIdSipAbstractLocator.TestTransportForWithNaptr;
begin
  Self.IP         := 'example.com';
  Self.Target.Uri := 'sip:' + Self.IP;

  // Values shamelessly stolen from RFC 3263, section 4.1
  // ;           order pref flags service      regexp  replacement
  //    IN NAPTR 50   50  "s"  "SIPS+D2T"     ""  _sips._tcp.example.com.
  //    IN NAPTR 90   50  "s"  "SIP+D2T"      ""  _sip._tcp.example.com
  //    IN NAPTR 100  50  "s"  "SIP+D2U"      ""  _sip._udp.example.com.
  Self.Loc.AddNAPTR(Self.IP,  50, 50, 's', NaptrTlsService, '_sips._tcp.example.com');
  Self.Loc.AddNAPTR(Self.IP,  90, 50, 's', NaptrTcpService, '_sip._tcp.example.com');
  Self.Loc.AddNAPTR(Self.IP, 100, 50, 's', NaptrUdpService, '_sip._udp.example.com');

  CheckEquals(Self.Loc.NAPTR[0].AsSipTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'Name, NAPTR records');
end;

procedure TestTIdSipAbstractLocator.TestTransportForWithoutNaptrAndNoSrv;
begin
  Self.IP         := 'example.com';
  Self.Target.Uri := 'sip:' + Self.IP;

  CheckEquals(UdpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Name, no NAPTR records, no SRV records');

  Self.Target.Scheme := SipsScheme;

  CheckEquals(TlsTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Name, no NAPTR records, no SRV records');
end;

procedure TestTIdSipAbstractLocator.TestTransportForWithoutNaptrWithSrv;
begin
  Self.IP         := 'example.com';
  Self.Target.Uri := 'sip:' + Self.IP;

  // Values shamelessly stolen from RFC 3263, section 4.1
  // ;;          Priority Weight Port   Target
  //     IN SRV  0        1      5060   server1.example.com
  //     IN SRV  0        2      5060   server2.example.com
  Self.Loc.AddSRV('example.com', '_sip._tcp', 0, 1, 5060, 'server1.example.com');
  Self.Loc.AddSRV('example.com', '_sip._tcp', 0, 2, 5060, 'server2.example.com');

  CheckEquals(TcpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIP, Name, no NAPTR records, but SRV records');

  Self.Target.Scheme := SipsScheme;
  CheckEquals(TcpTransport,
              Self.Loc.TransportFor(Self.Target,
                                    Self.Naptr,
                                    Self.Srv,
                                    Self.NameRecs),
              'SIPS, Name, no NAPTR records, but SRV records (none acceptable)');
end;

procedure TestTIdSipAbstractLocator.TestWithoutNaptrWithSrv;
var
  Locations: TIdSipLocations;
begin
  Self.IP         := 'example.com';
  Self.Target.Uri := 'sip:' + Self.IP;

  // Values shamelessly stolen from RFC 3263, section 4.1
  // ;;          Priority Weight Port   Target
  //     IN SRV  0        1      5060   server1.example.com
  //     IN SRV  0        2      5060   server2.example.com
  Self.Loc.AddSRV('example.com', '_sip._tcp', 0, 2, 5060, 'server1.example.com');
  Self.Loc.AddSRV('example.com', '_sip._tcp', 0, 1, 5060, 'server2.example.com');

  Self.Loc.AddA('server1.example.com', '127.0.0.1');
  Self.Loc.AddA('server2.example.com', '127.0.0.2');

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Check(Locations.Count > 1, 'Too few locations');
    CheckEquals('127.0.0.1', Locations[0].IPAddress, '1st record address');
    CheckEquals('127.0.0.2', Locations[1].IPAddress, '2nd record address');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameNaptrNoSrv;
var
  Locations: TIdSipLocations;
begin
  // The target's a domain name, we've NAPTR records from the transport lookup,
  // but no SRV RRs.
  Self.Target.Uri := 'sip:' + Self.Domain;
  Self.Loc.AddNAPTR(Self.Domain, 0, 0, NaptrDefaultFlags, NaptrTcpService,
                    '_sip._tcp.' + Self.Domain);
  Self.AddNameRecords(Self.Target.Host);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Self.CheckAorAAAARecords(Locations,
                             Self.Loc.NAPTR[0].AsSipTransport,
                             'NAPTR, no SRV');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameNaptrSrv;
var
  Locations: TIdSipLocations;
begin
  // The target's a domain name, we've NAPTR records from the transport lookup,
  // and we've SRV RRs.
  Self.Target.Uri := 'sip:' + Self.Domain;
  Self.Loc.AddNAPTR(Self.Domain, 0, 0, NaptrDefaultFlags, NaptrTlsService,
                    SrvTlsPrefix + '.' + Self.Domain);
  Self.Loc.AddNAPTR(Self.Domain, 1, 0, NaptrDefaultFlags, NaptrTcpService,
                    SrvTcpPrefix + '.' + Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvTlsPrefix, 0, 0, 0, Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix, 1, 0, 0, Self.Domain);

  Self.AddNameRecords(Self.Target.Host);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(4,                    Locations.Count,        'Location count');
    CheckEquals(TlsTransport,         Locations[0].Transport, '1st record Transport');
    CheckEquals(Self.ARecord,         Locations[0].IPAddress, '1st record IPAddress');
    CheckEquals(Self.Loc.SRV[0].Port, Locations[0].Port,      '1st record Port');
    CheckEquals(TlsTransport,         Locations[1].Transport, '2nd record Transport');
    CheckEquals(Self.AAAARecord,      Locations[1].IPAddress, '2nd record IPAddress');
    CheckEquals(Self.Loc.SRV[0].Port, Locations[1].Port,      '2nd record Port');

    CheckEquals(TcpTransport,         Locations[2].Transport, '3rd record Transport');
    CheckEquals(Self.ARecord,         Locations[2].IPAddress, '3rd record IPAddress');
    CheckEquals(Self.Loc.SRV[1].Port, Locations[2].Port,      '3rd record Port');
    CheckEquals(TcpTransport,         Locations[3].Transport, '4th record Transport');
    CheckEquals(Self.AAAARecord,      Locations[3].IPAddress, '4th record IPAddress');
    CheckEquals(Self.Loc.SRV[1].Port, Locations[3].Port,      '4th record Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameNoNaptrManualTransportNoSrv;
var
  Locations: TIdSipLocations;
begin
  // The target's a domain name, we've no NAPTR records from the transport lookup,
  // we've no SRV RRs, but we've a manually-specified transport.
  Self.Target.Uri := 'sip:' + Self.Domain + ';transport=' + TransportParamTLS_SCTP;
  Self.AddNameRecords(Self.Target.Host);

  Locations := TIdSipLocations.Create;
  try
    Self.CheckAorAAAARecords(Locations,
                             ParamToTransport(Self.Target.Transport),
                             'No NAPTR, no SRV, transport param');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameNoNaptrManualTransportSrv;
var
  Locations: TIdSipLocations;
begin
  // The target's a domain name, we've no NAPTR records from the transport lookup,
  // we've SRV RRs, and the transport's specified.

  Self.Target.Uri := 'sip:' + Self.Domain + ';transport=tls';

  Self.Loc.AddSRV(Self.Domain, SrvTlsPrefix, 0, 0, 0, Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix, 1, 0, 0, Self.Domain);

  Self.AddNameRecords(Self.Target.Host);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(2,                    Locations.Count,        'Location count');
    CheckEquals(TlsTransport,         Locations[0].Transport, '1st record Transport');
    CheckEquals(Self.ARecord,         Locations[0].IPAddress, '1st record IPAddress');
    CheckEquals(Self.Loc.SRV[0].Port, Locations[0].Port,      '1st record Port');
    CheckEquals(TlsTransport,         Locations[1].Transport, '2nd record Transport');
    CheckEquals(Self.AAAARecord,      Locations[1].IPAddress, '2nd record IPAddress');
    CheckEquals(Self.Loc.SRV[0].Port, Locations[1].Port,      '2nd record Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameNoNaptrNoManualTransportNoSrv;
var
  Locations: TIdSipLocations;
begin
  // A/AAAA lookup
  Self.Target.Uri := 'sips:' + Self.Domain;

  Self.Port := IdPORT_SIPS; // default for TLS
  Self.AddNameRecords(Self.Target.Host);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Self.CheckAorAAAARecords(Locations,
                             TlsTransport,
                             'No NAPTR, no SRV, no transport param');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameNoNaptrNoManualTransportSrv;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sip:' + Self.Domain;

  Self.AddNameRecords(Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvTlsPrefix, 0, 0, 0, Self.Domain);
  Self.Loc.AddSRV(Self.Domain, SrvTcpPrefix, 1, 0, 0, Self.Domain);

  // iterate over SRV
  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(4,                    Locations.Count,        'Location count');
    CheckEquals(TlsTransport,         Locations[0].Transport, '1st record Transport');
    CheckEquals(Self.ARecord,         Locations[0].IPAddress, '1st record IPAddress');
    CheckEquals(Self.Loc.SRV[0].Port, Locations[0].Port,      '1st record Port');
    CheckEquals(TlsTransport,         Locations[1].Transport, '2nd record Transport');
    CheckEquals(Self.AAAARecord,      Locations[1].IPAddress, '2nd record IPAddress');
    CheckEquals(Self.Loc.SRV[0].Port, Locations[1].Port,      '2nd record Port');

    CheckEquals(TcpTransport,         Locations[2].Transport, '3rd record Transport');
    CheckEquals(Self.ARecord,         Locations[2].IPAddress, '3rd record IPAddress');
    CheckEquals(Self.Loc.SRV[1].Port, Locations[2].Port,      '3rd record Port');
    CheckEquals(TcpTransport,         Locations[3].Transport, '4th record Transport');
    CheckEquals(Self.AAAARecord,      Locations[3].IPAddress, '4th record IPAddress');
    CheckEquals(Self.Loc.SRV[1].Port, Locations[3].Port,      '4th record Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNameWithPort;
var
  Locations: TIdSipLocations;
begin
  Self.AddNameRecords(Self.Target.Host);

  Self.Target.Uri := 'sip:' + Self.Domain + ':' + IntToStr(Self.Port);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Self.CheckAorAAAARecords(Locations, UdpTransport, 'SIP URI');
  finally
    Locations.Free;
  end;

  Self.Target.Scheme := SipsScheme;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    Self.CheckAorAAAARecords(Locations, TlsTransport, 'SIPS URI');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNumericAddress;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sip:' + Self.IP;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(1,            Locations.Count,        'SIP Location count');
    CheckEquals(UdpTransport, Locations[0].Transport, 'SIP Transport');
    CheckEquals(Self.IP,      Locations[0].IPAddress, 'SIP IPAddress');
    CheckEquals(IdPORT_SIP,   Locations[0].Port,      'SIP Port');
  finally
    Locations.Free;
  end;

  Self.Target.Scheme := SipsScheme;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(1,            Locations.Count,        'SIPS Location count');
    CheckEquals(TlsTransport, Locations[0].Transport, 'SIPS Transport');
    CheckEquals(Self.IP,      Locations[0].IPAddress, 'SIPS IPAddress');
    CheckEquals(IdPORT_SIPS,  Locations[0].Port,      'SIPS Port');
  finally
    Locations.Free;
  end;
end;

procedure TestTIdSipAbstractLocator.TestFindServersForNumericAddressWithPort;
var
  Locations: TIdSipLocations;
begin
  Self.Target.Uri := 'sip:' + Self.IP + ':' + IntToStr(Self.Port);

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(1,            Locations.Count,        'SIP Location count');
    CheckEquals(UdpTransport, Locations[0].Transport, 'SIP Transport');
    CheckEquals(Self.IP,      Locations[0].IPAddress, 'SIP IPAddress');
    CheckEquals(Self.Port,    Locations[0].Port,      'SIP Port');
  finally
    Locations.Free;
  end;

  Self.Target.Scheme := SipsScheme;

  Locations := Self.Loc.FindServersFor(Self.Target);
  try
    CheckEquals(1,            Locations.Count,        'SIPS Location count');
    CheckEquals(TlsTransport, Locations[0].Transport, 'SIPS Transport');
    CheckEquals(Self.IP,      Locations[0].IPAddress, 'SIPS IPAddress');
    CheckEquals(Self.Port,    Locations[0].Port,      'SIPS Port');
  finally
    Locations.Free;
  end;
end;

//******************************************************************************
//* TestTIdSipMockLocator                                                      *
//******************************************************************************
//* TestTIdSipMockLocator Public methods ***************************************

procedure TestTIdSipMockLocator.SetUp;
begin
  inherited SetUp;

  Self.AOR := TIdUri.Create('sip:bar');
  Self.Loc := TIdSipMockLocator.Create;
end;

procedure TestTIdSipMockLocator.TearDown;
begin
  Self.Loc.Free;

  inherited TearDown;
end;

//* TestTIdSipMockLocator Published methods ************************************

procedure TestTIdSipMockLocator.TestLookupCount;
var
  Names: TIdDomainNameRecords;
  Naptr: TIdNaptrRecords;
  Srv:   TIdSrvRecords;
begin
  CheckEquals(0, Self.Loc.LookupCount, 'Initial value');

  Names := TIdDomainNameRecords.Create;
  try
    Self.Loc.ResolveNameRecords('', Names);

    CheckEquals(1,
                Self.Loc.LookupCount,
                'LookuCount after name lookup');
  finally
    Names.Free;
  end;

  Naptr := TIdNaptrRecords.Create;
  try
    Self.Loc.ResolveNAPTR(Self.AOR, Naptr);

    CheckEquals(2,
                Self.Loc.LookupCount,
                'LookuCount after NAPTR lookup');
  finally
    Naptr.Free;
  end;

  Srv := TIdSrvRecords.Create;
  try
    Self.Loc.ResolveSRV('', Srv);

    CheckEquals(3,
                Self.Loc.LookupCount,
                'LookuCount after SRV lookup');
  finally
    Srv.Free;
  end;

  Self.Loc.ResetLookupCount;
  CheckEquals(0, Self.Loc.LookupCount, 'After ResetLookupCount');
end;

procedure TestTIdSipMockLocator.TestResolveNameRecords;
var
  Results: TIdDomainNameRecords;
begin
  // All mixed up records
  Self.Loc.AddA('foo',            '127.0.0.3');
  Self.Loc.AddA(Self.AOR.Host,    '127.0.0.1');
  Self.Loc.AddAAAA(Self.AOR.Host, '::1');
  Self.Loc.AddAAAA(Self.AOR.Host, '::2');
  Self.Loc.AddA(Self.AOR.Host,    '127.0.0.2');
  Self.Loc.AddAAAA('foo',         '::3');

  Results := TIdDomainNameRecords.Create;
  try
    Self.Loc.ResolveNameRecords(Self.AOR.Host, Results);

    CheckEquals(4,
                Results.Count,
                'Incorrect number of results: unwanted records added?');

    CheckEquals('127.0.0.1', Results[0].IPAddress, '1st record');
    CheckEquals('::1',       Results[1].IPAddress, '2nd record');
    CheckEquals('::2',       Results[2].IPAddress, '3rd record');
    CheckEquals('127.0.0.2', Results[3].IPAddress, '4th record');
  finally
    Results.Free;
  end;
end;

procedure TestTIdSipMockLocator.TestResolveNAPTRSip;
var
  Results: TIdNaptrRecords;
begin
  Self.Loc.AddNAPTR(AOR.Host, 10, 10, 's', 'http+foo', 'foo.bar');
  Self.Loc.AddNAPTR(AOR.Host, 20, 10, 's', 'SIP+D2T',  '_sip._tcp.bar');
  Self.Loc.AddNAPTR(AOR.Host, 10, 10, 's', 'SIPS+D2T', '_sips._tcp.bar');
  Self.Loc.AddNAPTR(AOR.Host, 30, 10, 's', 'SIP+D2U',  '_sip._udp.bar');
  Self.Loc.AddNAPTR('foo',    30, 10, 's', 'SIP+D2U',  '_sip._udp.foo');

  Results := TIdNaptrRecords.Create;
  try
    Self.Loc.ResolveNAPTR(Self.AOR, Results);
    CheckEquals(3,
                Results.Count,
                'Incorrect number of results: unwanted records added?');

    CheckEquals('_sips._tcp.bar', Results[0].Value, '1st record');
    CheckEquals('_sip._tcp.bar',  Results[1].Value, '2nd record');
    CheckEquals('_sip._udp.bar',  Results[2].Value, '3rd record');
  finally
    Results.Free;
  end;
end;

procedure TestTIdSipMockLocator.TestResolveNAPTRSips;
var
  Results: TIdNaptrRecords;
begin
  Self.Loc.AddNAPTR(AOR.Host, 10, 10, 's', 'http+foo', 'foo.bar');
  Self.Loc.AddNAPTR(AOR.Host, 20, 10, 's', 'SIP+D2T',  '_sip._tcp.bar');
  Self.Loc.AddNAPTR(AOR.Host, 10, 10, 's', 'SIPS+D2T', '_sips._tcp.bar');
  Self.Loc.AddNAPTR(AOR.Host, 30, 10, 's', 'SIP+D2U',  '_sip._udp.bar');
  Self.Loc.AddNAPTR('foo',    30, 10, 's', 'SIP+D2U',  '_sip._udp.foo');

  Results := TIdNaptrRecords.Create;
  try
    Self.AOR.Scheme := SipsScheme;
    Self.Loc.ResolveNAPTR(Self.AOR, Results);
    CheckEquals(1,
                Results.Count,
                'Incorrect number of results: unwanted records added?');
    CheckEquals('_sips._tcp.bar', Results[0].Value, '1st record');
  finally
    Results.Free;
  end;
end;

procedure TestTIdSipMockLocator.TestResolveSRV;
var
  Results: TIdSrvRecords;
begin
  Self.Loc.AddSRV('foo.bar', SrvTlsPrefix,  0, 0, IdPORT_SIPS, 'paranoid.bar');
  Self.Loc.AddSRV('foo.bar', SrvTcpPrefix, 10, 1, IdPORT_SIP , 'backup.bar');
  Self.Loc.AddSRV('foo.bar', SrvTcpPrefix, 10, 2, IdPORT_SIP , 'normal.bar');
  Self.Loc.AddSRV('foo.bar', SrvTcpPrefix, 20, 0, IdPORT_SIP , 'fallback.bar');
  Self.Loc.AddSRV('boo.far', SrvTlsPrefix,  0, 0, IdPORT_SIPS, 'paranoid.far');

  Results := TIdSrvRecords.Create;
  try
    Self.Loc.ResolveSRV('_sip._tcp.foo.bar', Results);

    CheckEquals(3,
                Results.Count,
                'Incorrect number of results: unwanted records added?');

    CheckEquals('normal.bar',   Results[0].Target, '1st record');
    CheckEquals('backup.bar',   Results[1].Target, '2nd record');
    CheckEquals('fallback.bar', Results[2].Target, '3rd record');
  finally
    Results.Free;
  end;
end;

procedure TestTIdSipMockLocator.TestResolveSRVWithNameRecords;
var
  Results: TIdSrvRecords;
begin
  Self.Loc.AddSRV('foo.bar', SrvTlsPrefix,  0, 0, IdPORT_SIPS, 'paranoid.bar');
  Self.Loc.AddAAAA('paranoid.bar', '::1');
  Self.Loc.AddA(   'arbitrary',    '127.0.0.2');
  Self.Loc.AddA(   'paranoid.bar', '127.0.0.1');

  Results := TIdSrvRecords.Create;
  try
    Self.Loc.ResolveSRV('_sips._tcp.foo.bar', Results);

    Check(not Results.IsEmpty, 'No results found');
    CheckEquals(2, Results[0].NameRecords.Count, 'Name record count');
    CheckEquals('::1',       Results[0].NameRecords[0].IPAddress, '1st name record');
    CheckEquals('127.0.0.1', Results[0].NameRecords[1].IPAddress, '2nd name record');
  finally
    Results.Free;
  end;
end;

initialization
  // Some tests use SCTP.
  TIdSipTransport.RegisterTransport(SctpTransport, TIdSipSctpTransport);

  RegisterTest('SIP Location Services', Suite);
end.
