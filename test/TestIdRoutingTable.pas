{
  (c) 2007 Directorate of New Technologies, Royal National Institute for Deaf people (RNID)

  The RNID licence covers this unit. Read the licence at:
      http://www.ictrnid.org.uk/docs/gw/rnid_license.txt

  This unit contains code written by:
    * Frank Shearar
}
unit TestIdRoutingTable;

interface

uses
  IdMockRoutingTable, IdRoutingTable, TestFramework;

type
  TestTIdRouteEntry = class(TTestCase)
  private
    Route: TIdRouteEntry;
  protected
    function MakeRoute: TIdRouteEntry; virtual;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestClone;
    procedure TestEquals; virtual;
    procedure TestEqualsDestinationDiffers;
    procedure TestEqualsGatewayDiffers;
    procedure TestEqualsInterfaceIndexDiffers;
    procedure TestEqualsMaskDiffers;
    procedure TestEqualsMetricDiffers;
    procedure TestIsDefaultRoute;
    procedure TestIsIPv4Address;
    procedure TestIsMappedRoute; virtual;
    procedure TestSetDestination;
    procedure TestSetDestinationIPv6;
    procedure TestSetDestInetAddr;
    procedure TestSetMask;
    procedure TestSetMaskInetAddr;
    procedure TestWillRoute;
    procedure TestWillRouteIpv6;
  end;

  // While we use a mock routing table in these tests, note that the algorithms
  // under test cannot be overridden by subclasses. Ergo, real routing tables
  // will work the same way.
  TestTIdIPv4RoutingTable = class(TTestCase)
  private
    InternetDestination: String;
    InternetGateway:     String;
    InternetIP:          String;
    InternetMask:        String;
    InternetRoute:       String;
    LanDestination:      String;
    LanGateway:          String;
    LanIP:               String;
    LanMask:             String;
    LanRoute:            String;
    LoopbackDestination: String;
    LoopbackGateway:     String;
    LoopbackIP:          String;
    LoopbackMask:        String;
    LoopbackRoute:       String;
    VpnDestination:      String;
    VpnGateway:          String;
    VpnIP:               String;
    VpnMask:             String;
    VpnRoute:            String;

    RouteA:   TIdRouteEntry;
    RouteB:   TIdRouteEntry;
    RT:       TIdMockRoutingTable;

    procedure AddDefaultRoute(Gateway, LocalAddress: String);
    procedure AddInternetRoute;
    procedure AddLanRoute;
    procedure AddLoopbackRoute;
    procedure AddVpnRoute;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAddMappedRouteAndCount;
    procedure TestHasRoute;
    procedure TestLocalAddressForInternetGateway;
    procedure TestLocalAddressForNoMappedRoutes;
    procedure TestLocalAddressForMappedRouteToInternet;
    procedure TestLocalAddressForMappedRouteToInternetAndVpn;
    procedure TestLocalAddressForMappedRouteToVpn;
    procedure TestLocalAddressForMultipleLansPlusMultipleMappedRoutes;
    procedure TestLocalAddressForNoRoutes;
    procedure TestRemoveRoute;
    procedure TestRouteSortDestinationAndMaskDiffers;
    procedure TestRouteSortGatewayAndMetricDiffers;
    procedure TestRouteSortIPv4RoutesFirst;
    procedure TestRouteSortMetricDiffers;
    procedure TestRouteSortOneRouteAMappedRoute;
    procedure TestRouteSortOnlyDestinationDiffers;
    procedure TestRouteSortOnlyGatewayDiffers;
    procedure TestRouteSortOnlyMaskDiffers;
    procedure TestRouteSortOnlyMetricDiffers;
    procedure TestRouteSortSameRoute;
  end;

implementation

uses
  IdSimpleParser, SysUtils;

function Suite: ITestSuite;
begin
  Result := TTestSuite.Create('IdSystem unit tests');
  Result.AddTest(TestTIdRouteEntry.Suite);
  Result.AddTest(TestTIdIPv4RoutingTable.Suite);
end;

//******************************************************************************
//* TestTIdRouteEntry                                                          *
//******************************************************************************
//* TestTIdRouteEntry Public methods *******************************************

procedure TestTIdRouteEntry.SetUp;
begin
  inherited SetUp;

  Self.Route := Self.MakeRoute;
  Self.Route.Destination    := '10.0.0.0';
  Self.Route.Gateway        := '10.0.0.1';
  Self.Route.InterfaceIndex := 'rl0';
  Self.Route.LocalAddress   := '10.0.0.6';
  Self.Route.Mask           := '255.0.0.0';
  Self.Route.Metric         := 1;
end;

procedure TestTIdRouteEntry.TearDown;
begin
  Self.Route.Free;

  inherited SetUp;
end;

//* TestTIdRouteEntry Protected methods ****************************************

function TestTIdRouteEntry.MakeRoute: TIdRouteEntry;
begin
  Result := TIdRouteEntry.Create;
end;

//* TestTIdRouteEntry Published methods ****************************************

procedure TestTIdRouteEntry.TestClone;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    CheckEquals(Self.Route.Destination,    Other.Destination,    'Destination');
    CheckEquals(Self.Route.Gateway,        Other.Gateway,        'Gateway');
    CheckEquals(Self.Route.InterfaceIndex, Other.InterfaceIndex, 'InterfaceIndex');
    CheckEquals(Self.Route.IsMappedRoute,  Other.IsMappedRoute,  'IsMappedRoute');
    CheckEquals(Self.Route.LocalAddress,   Other.LocalAddress,   'LocalAddress');
    CheckEquals(Self.Route.Mask,           Other.Mask,           'Mask');
    CheckEquals(Self.Route.Metric,         Other.Metric,         'Metric');

  finally
    Other.Free;
  end;
end;  

procedure TestTIdRouteEntry.TestEquals;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    Check(Self.Route.Equals(Other), 'Self.Route must equal Other');
    Check(Other.Equals(Self.Route), 'Equals must be reflexive');
  finally
    Other.Free;
  end;
end;

procedure TestTIdRouteEntry.TestEqualsDestinationDiffers;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    Other.Destination := TIdIPAddressParser.IncIPAddress(Self.Route.Destination);
    Check(not Self.Route.Equals(Other), 'Self.Route <> Other because their destinations differ');
    Check(not Other.Equals(Self.Route), 'Equals must be reflexive');
  finally
    Other.Free;
  end;
end;

procedure TestTIdRouteEntry.TestEqualsGatewayDiffers;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    Other.Gateway := TIdIPAddressParser.IncIPAddress(Self.Route.Gateway);
    Check(not Self.Route.Equals(Other), 'Self.Route <> Other because their gateways differ');
    Check(not Other.Equals(Self.Route), 'Equals must be reflexive');
  finally
    Other.Free;
  end;
end;

procedure TestTIdRouteEntry.TestEqualsInterfaceIndexDiffers;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    Other.InterfaceIndex := Self.Route.InterfaceIndex + '1';
    Check(Self.Route.Equals(Other), 'InterfaceIndexes are irrelevant for route comparison');
    Check(Other.Equals(Self.Route), 'Equals must be reflexive');
  finally
    Other.Free;
  end;
end;

procedure TestTIdRouteEntry.TestEqualsMaskDiffers;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    Other.Mask := TIdIPAddressParser.IncIPAddress(Self.Route.Mask);
    Check(not Self.Route.Equals(Other), 'Self.Route <> Other because their masks differ');
    Check(not Other.Equals(Self.Route), 'Equals must be reflexive');
  finally
    Other.Free;
  end;
end;

procedure TestTIdRouteEntry.TestEqualsMetricDiffers;
var
  Other: TIdRouteEntry;
begin
  Other := Self.Route.Clone;
  try
    Other.Metric := Self.Route.Metric + 1;
    Check(Self.Route.Equals(Other), 'Metrics are irrelevant for route comparison');
    Check(Other.Equals(Self.Route), 'Equals must be reflexive');
  finally
    Other.Free;
  end;
end;

procedure TestTIdRouteEntry.TestIsDefaultRoute;
begin
  Self.Route.Destination := '1.1.1.1';
  Check(not Self.Route.IsDefaultRoute, '1.1.1.1');

  Self.Route.Destination := '0.0.0.0';
  Check(Self.Route.IsDefaultRoute, '0.0.0.0');

  Self.Route.Destination := '2002::';
  Check(not Self.Route.IsDefaultRoute, '2002::');

  Self.Route.Destination := '::';
  Check(Self.Route.IsDefaultRoute, '::');

  Self.Route.Destination := '0:0:0:0:0:0:0:0';
  Check(Self.Route.IsDefaultRoute, '0:0:0:0:0:0:0:0');

  Self.Route.Destination := '00:00:00:00:00:00:00:00';
  Check(Self.Route.IsDefaultRoute, '00:00:00:00:00:00:00:00');

  // And lastly, malformed destinations:
  Self.Route.Destination := 'abcd';
  Check(not Self.Route.IsDefaultRoute, 'abcd');

  Self.Route.Destination := '';
  Check(not Self.Route.IsDefaultRoute, 'The empty string');
end;

procedure TestTIdRouteEntry.TestIsIPv4Address;
const
  IPv4Destination      = '0.0.0.0';
  IPv6Destination      = '::';
  MalformedDestination = '';
begin
  Self.Route.Destination := IPv4Destination;
  Check(Self.Route.IsIPv4Route, 'IPv4 route');

  Self.Route.Destination := IPv6Destination;
  Check(not Self.Route.IsIPv4Route, 'IPv6 route');

  Self.Route.Destination := MalformedDestination;
  Check(not Self.Route.IsIPv4Route, 'Malformed route');
end;

procedure TestTIdRouteEntry.TestIsMappedRoute;
begin
  Check(not Self.Route.IsMappedRoute, 'Normal route looks like a mapped route');
end;

procedure TestTIdRouteEntry.TestSetDestination;
const
  Destination        = '10.0.0.0';
  DestInetAddr       = $0a000000;
  SecondDestination  = '10.0.1.0';
  SecondDestInetAddr = $0a000100;
begin
  Self.Route.Destination := Destination;
  CheckEquals(Destination, Self.Route.Destination, 'Destination not set');
  CheckEquals(IntToHex(DestInetAddr, 8),
              IntToHex(Self.Route.DestInetAddrIPv4, 8),
              'DestInetAddrIPv4 not set');

  Self.Route.Destination := SecondDestination;
  CheckEquals(SecondDestination, Self.Route.Destination, 'Destination not reset');
  CheckEquals(IntToHex(SecondDestInetAddr, 8),
              IntToHex(Self.Route.DestInetAddrIPv4, 8),
              'DestInetAddrIPv4 not reset');
end;

procedure TestTIdRouteEntry.TestSetDestinationIPv6;
const
  Destination = '::';
begin
  Self.Route.Destination := Destination;
  CheckEquals(Destination, Self.Route.Destination, 'Destination not set');
  CheckEquals(IntToHex(0, 8),
              IntToHex(Self.Route.DestInetAddrIPv4, 8),
              'DestInetAddrIPv4 set');
end;

procedure TestTIdRouteEntry.TestSetDestInetAddr;
const
  Destination        = '10.0.0.0';
  DestInetAddr       = $0a000000;
  SecondDestination  = '10.0.1.0';
  SecondDestInetAddr = $0a000100;
begin
  Self.Route.DestInetAddrIPv4 := DestInetAddr;
  CheckEquals(Destination, Self.Route.Destination, 'Destination not set');
  CheckEquals(IntToHex(DestInetAddr, 8),
              IntToHex(Self.Route.DestInetAddrIPv4, 8),
              'DestInetAddrIPv4 not set');

  Self.Route.DestInetAddrIPv4 := SecondDestInetAddr;
  CheckEquals(SecondDestination, Self.Route.Destination, 'Destination not reset');
  CheckEquals(IntToHex(SecondDestInetAddr, 8),
              IntToHex(Self.Route.DestInetAddrIPv4, 8),
              'DestInetAddrIPv4 not reset');
end;

procedure TestTIdRouteEntry.TestSetMask;
const
  Mask               = '255.0.0.0';
  MaskInetAddr       = $ff000000;
  SecondMask         = '255.255.0.0';
  SecondMaskInetAddr = $ffff0000;
begin
  Self.Route.Mask := Mask;
  CheckEquals(Mask, Self.Route.Mask, 'Mask not set');
  CheckEquals(IntToHex(MaskInetAddr, 8),
              IntToHex(Self.Route.MaskInetAddrIPv4, 8),
              'MaskInetAddrIPv4 not set');

  Self.Route.Mask := SecondMask;
  CheckEquals(SecondMask, Self.Route.Mask, 'Mask not reset');
  CheckEquals(IntToHex(SecondMaskInetAddr, 8),
              IntToHex(Self.Route.MaskInetAddrIPv4, 8),
              'MaskInetAddrIPv4 not reset');
end;

procedure TestTIdRouteEntry.TestSetMaskInetAddr;
const
  Mask               = '255.0.0.0';
  MaskInetAddr       = $ff000000;
  SecondMask         = '255.255.0.0';
  SecondMaskInetAddr = $ffff0000;
begin
  Self.Route.MaskInetAddrIPv4 := MaskInetAddr;
  CheckEquals(Mask, Self.Route.Mask, 'Mask not set');
  CheckEquals(IntToHex(MaskInetAddr, 8),
              IntToHex(Self.Route.MaskInetAddrIPv4, 8),
              'MaskInetAddrIPv4 not set');

  Self.Route.MaskInetAddrIPv4 := SecondMaskInetAddr;
  CheckEquals(SecondMask, Self.Route.Mask, 'Mask not reset');
  CheckEquals(IntToHex(SecondMaskInetAddr, 8),
              IntToHex(Self.Route.MaskInetAddrIPv4, 8),
              'MaskInetAddrIPv4 not reset');
end;

procedure TestTIdRouteEntry.TestWillRoute;
begin
  Self.Route.Destination := '127.0.0.0';
  Self.Route.Mask        := '255.0.0.0';

  Check(    Self.Route.WillRoute('127.0.0.1'), '127.0.0.0/8 + 127.0.0.1');
  Check(    Self.Route.WillRoute('127.0.0.2'), '127.0.0.0/8 + 127.0.0.2');
  Check(    Self.Route.WillRoute('127.0.1.1'), '127.0.0.0/8 + 127.0.1.1');
  Check(    Self.Route.WillRoute('127.1.0.1'), '127.0.0.0/8 + 127.1.0.1');
  Check(not Self.Route.WillRoute('128.0.0.1'), '127.0.0.0/8 + 128.0.0.1');
  Check(not Self.Route.WillRoute('2002:deca:fbad::1'), '127.0.0.0/8 + 2002:deca:fbad::1');

  Self.Route.Destination := '127.0.0.1';
  Self.Route.Mask        := '255.255.0.0';
  Check(    Self.Route.WillRoute('127.0.0.1'), '127.0.0.0/16 + 127.0.0.1');
  Check(    Self.Route.WillRoute('127.0.0.2'), '127.0.0.0/16 + 127.0.0.2');
  Check(   Self.Route.WillRoute('127.0.1.1'), '127.0.0.0/16 + 127.0.1.1');
  Check(not Self.Route.WillRoute('127.1.0.1'), '127.0.0.0/16 + 127.1.0.1');
  Check(not Self.Route.WillRoute('128.0.0.1'), '127.0.0.0/16 + 128.0.0.1');
  Check(not Self.Route.WillRoute('2002:deca:fbad::1'), '127.0.0.0/16 + 2002:deca:fbad::1');

  Self.Route.Destination := '127.0.0.1';
  Self.Route.Mask        := '255.255.255.0';
  Check(    Self.Route.WillRoute('127.0.0.1'), '127.0.0.0/24 + 127.0.0.1');
  Check(    Self.Route.WillRoute('127.0.0.2'), '127.0.0.0/24 + 127.0.0.2');
  Check(not Self.Route.WillRoute('127.0.1.1'), '127.0.0.0/24 + 127.0.1.1');
  Check(not Self.Route.WillRoute('127.1.0.1'), '127.0.0.0/24 + 127.1.0.1');
  Check(not Self.Route.WillRoute('128.0.0.1'), '127.0.0.0/24 + 128.0.0.1');
  Check(not Self.Route.WillRoute('2002:deca:fbad::1'), '127.0.0.0/24 + 2002:deca:fbad::1');

  Self.Route.Destination := '127.0.0.1';
  Self.Route.Mask        := '255.255.255.255';
  Check(    Self.Route.WillRoute('127.0.0.1'), '127.0.0.0/32 + 127.0.0.1');
  Check(not Self.Route.WillRoute('127.0.0.2'), '127.0.0.0/32 + 127.0.0.2');
  Check(not Self.Route.WillRoute('127.0.1.1'), '127.0.0.0/32 + 127.0.1.1');
  Check(not Self.Route.WillRoute('127.1.0.1'), '127.0.0.0/32 + 127.1.0.1');
  Check(not Self.Route.WillRoute('128.0.0.1'), '127.0.0.0/32 + 128.0.0.1');
  Check(not Self.Route.WillRoute('2002:deca:fbad::1'), '127.0.0.0/32 + 2002:deca:fbad::1');
end;

procedure TestTIdRouteEntry.TestWillRouteIpv6;
begin
  Self.Route.Destination := '::';
  Self.Route.Mask        := '::';
  Check(not Self.Route.WillRoute('127.0.0.1'), '::/0 + 127.0.0.1');
  Check(Self.Route.WillRoute('::1'), '::/0 + ::1');
  Check(Self.Route.WillRoute('::1:1'), '::/0 + ::1:1');
  Check(Self.Route.WillRoute('::1:1:1'), '::/0 + ::1:1:1');
  Check(Self.Route.WillRoute('::1:1:1:1'), '::/0 + ::1:1:1:1');
  Check(Self.Route.WillRoute('::1:1:1:1:1'), '::/0 + ::1:1:1:1:1');
  Check(Self.Route.WillRoute('::1:1:1:1:1:1'), '::/0 + ::1:1:1:1:1:1');
  Check(Self.Route.WillRoute('::1:1:1:1:1:1:1'), '::/0 + ::1:1:1:1:1:1:1');
  Check(Self.Route.WillRoute('1:1:1:1:1:1:1:1'), '::/0 + 1:1:1:1:1:1:1:1');
end;

//******************************************************************************
//* TestTIdIPv4RoutingTable                                                    *
//******************************************************************************
//* TestTIdIPv4RoutingTable Public methods *************************************

procedure TestTIdIPv4RoutingTable.SetUp;
begin
  inherited SetUp;

  Self.RouteA := TIdRouteEntry.Create;
  Self.RouteA.Destination    := '10.0.0.0';
  Self.RouteA.Gateway        := '10.0.0.1';
  Self.RouteA.InterfaceIndex := '1';
  Self.RouteA.Mask           := '255.0.0.0';
  Self.RouteA.Metric         := 1;

  Self.RouteB := TIdRouteEntry.Create;
  Self.RouteB.Destination    := Self.RouteA.Destination;
  Self.RouteB.Gateway        := Self.RouteA.Gateway;
  Self.RouteB.InterfaceIndex := Self.RouteA.InterfaceIndex;
  Self.RouteB.Mask           := Self.RouteA.Mask;
  Self.RouteB.Metric         := Self.RouteA.Metric;

  Self.RT := TIdMockRoutingTable.Create;

  // These settings are pretty arbitrary; they're more or less the author's
  // setup.
  Self.InternetDestination := '1.2.3.4';
  Self.InternetGateway     := '41.241.0.1';
  Self.InternetIP          := '41.241.2.134';
  Self.InternetMask        := '0.0.0.0';
  Self.InternetRoute       := '0.0.0.0';
  Self.LanDestination      := '10.0.0.8';
  Self.LanGateway          := '10.0.0.1';
  Self.LanIP               := '10.0.0.6';
  Self.LanMask             := '255.0.0.0';
  Self.LanRoute            := '10.0.0.0';
  Self.LoopbackDestination := '127.0.0.2';
  Self.LoopbackGateway     := '127.0.0.1';
  Self.LoopbackIP          := '127.0.0.1';
  Self.LoopbackMask        := '255.0.0.0';
  Self.LoopbackRoute       := '127.0.0.0';
  Self.VpnDestination      := '192.168.0.43';
  Self.VpnGateway          := '192.168.0.1';
  Self.VpnIP               := '192.168.0.42';
  Self.VpnMask             := '255.255.255.0';
  Self.VpnRoute            := '192.168.0.0';
end;

procedure TestTIdIPv4RoutingTable.TearDown;
begin
  Self.RouteB.Free;
  Self.RouteA.Free;
  Self.RT.Free;

  inherited TearDown;
end;

//* TestTIdIPv4RoutingTable Private methods ************************************

procedure TestTIdIPv4RoutingTable.AddDefaultRoute(Gateway, LocalAddress: String);
begin
  Self.RT.AddOsRoute('0.0.0.0', '0.0.0.0', Gateway, 1, '1', LocalAddress);
end;

procedure TestTIdIPv4RoutingTable.AddInternetRoute;
begin
  Self.RT.AddOsRoute(Self.InternetRoute, Self.InternetGateway, Self.InternetMask, 1, '1', Self.InternetIP);
end;

procedure TestTIdIPv4RoutingTable.AddLanRoute;
begin
  Self.RT.AddOsRoute(Self.LanRoute, Self.LanGateway, Self.LanMask, 1, '1', Self.LanIP);
end;

procedure TestTIdIPv4RoutingTable.AddLoopbackRoute;
begin
  Self.RT.AddOsRoute(Self.LoopbackRoute, Self.LoopbackGateway, Self.LoopbackMask, 1, '1', Self.LoopbackIP);
end;

procedure TestTIdIPv4RoutingTable.AddVpnRoute;
begin
  Self.RT.AddOsRoute(Self.VpnRoute, Self.VpnGateway, Self.VpnMask, 1, '1', Self.VpnIP);
end;

//* TestTIdIPv4RoutingTable Published methods **********************************

procedure TestTIdIPv4RoutingTable.TestAddMappedRouteAndCount;
begin
  CheckEquals(0, Self.RT.RouteCount, 'Empty list');

  Self.RT.AddMappedRoute('1.2.3.4', '255.255.255.255', '4.3.2.1');
  CheckEquals(1, Self.RT.RouteCount, 'One mapped route');

  Self.RT.AddMappedRoute('1.2.3.4', '255.255.255.255', '4.3.2.1');
  CheckEquals(1, Self.RT.RouteCount, 'Duplicate mapped route added');

  Self.RT.AddMappedRoute('1.2.3.5', '255.255.255.255', '5.3.2.1');
  CheckEquals(2, Self.RT.RouteCount, 'Two mapped routes');
end;

procedure TestTIdIPv4RoutingTable.TestHasRoute;
begin
  Check(not Self.RT.HasRoute(Self.RouteA), 'Empty table');

  Self.RT.AddMappedRoute(Self.RouteA.Destination, Self.RouteA.Mask, Self.RouteA.Gateway);
  Check(Self.RT.HasRoute(Self.RouteA), 'Route not added? not found?');
  Check(Self.RT.HasRoute(Self.RouteB), 'Duplicate of in-table route not found');

  Self.RouteB.Destination := TIdIPAddressParser.IncIPAddress(Self.RouteB.Destination);
  Check(not Self.RT.HasRoute(Self.RouteB), 'Route not in table still found');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForInternetGateway;
begin
  // Scenario: A machine with a LAN IP, and a gateway to the internet.
  // Even though the internet gateway's a NAT, we've not specified a mapped
  // route through it.
  Self.AddLoopbackRoute;
  Self.AddLanRoute;
  Self.AddDefaultRoute(Self.LanGateway, Self.LanIP);

  CheckEquals(Self.LoopbackIP, Self.RT.LocalAddressFor(Self.LoopbackDestination), 'Local destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.LanDestination),      'LAN destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.InternetDestination), 'Internet destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.VpnDestination),      'VPN destination');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForNoMappedRoutes;
begin
  // Scenario: A machine with a LAN IP, with no gateway (say, to the internet).
  Self.AddLoopbackRoute;
  Self.AddLanRoute;
  Self.AddDefaultRoute(Self.LanGateway, Self.LanIP);

  CheckEquals(Self.LoopbackIP, Self.RT.LocalAddressFor(Self.LoopbackDestination), 'Local destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.LanDestination),      'LAN destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.InternetDestination), 'Internet destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.VpnDestination),      'VPN destination');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForMappedRouteToInternet;
begin
  // Scenario: A machine with a LAN IP, and a gateway to the internet.
  // One mapped route, because the internet gateway's a NAT.
  Self.AddLoopbackRoute;
  Self.AddLanRoute;
  Self.AddDefaultRoute(Self.InternetGateway, Self.LanIP);

  Self.RT.AddMappedRoute(Self.InternetRoute, Self.InternetMask, Self.InternetIP);

  CheckEquals(Self.LoopbackIP, Self.RT.LocalAddressFor(Self.LoopbackDestination), 'Local destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.LanDestination),      'LAN destination');
  CheckEquals(Self.InternetIP, Self.RT.LocalAddressFor(Self.InternetDestination), 'Internet destination');
  CheckEquals(Self.InternetIP, Self.RT.LocalAddressFor(Self.VpnDestination),      'VPN destination');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForMappedRouteToInternetAndVpn;
begin
  // Scenario: A machine with a LAN IP, and both a gateway to the internet and
  // a gateway to another network. (This is the situation for the author.)
  // The default route will use the LAN IP.
  Self.AddLoopbackRoute;
  Self.AddLanRoute;
  Self.AddDefaultRoute(Self.InternetGateway, Self.LanIP);

  Self.RT.AddMappedRoute(Self.InternetRoute, Self.InternetMask, Self.InternetIP);
  Self.RT.AddMappedRoute(Self.VpnRoute, Self.VpnMask, Self.VpnIP);

  CheckEquals(Self.LoopbackIP, Self.RT.LocalAddressFor(Self.LoopbackDestination), 'Local destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.LanDestination),      'LAN destination');
  CheckEquals(Self.InternetIP, Self.RT.LocalAddressFor(Self.InternetDestination), 'Internet destination');
  CheckEquals(Self.VpnIP,      Self.RT.LocalAddressFor(Self.VpnDestination),      'VPN destination');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForMappedRouteToVpn;
begin
  // Scenario: A machine with a LAN IP, and a gateway to another network.
  // There's no internet gateway, so the default route will use the LAN IP.
  Self.AddLoopbackRoute;
  Self.AddLanRoute;
  Self.AddDefaultRoute(Self.InternetGateway, Self.LanIP);

  Self.RT.AddMappedRoute(Self.VpnRoute, Self.VpnMask, Self.VpnIP);

  CheckEquals(Self.LoopbackIP, Self.RT.LocalAddressFor(Self.LoopbackDestination), 'Local destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.LanDestination),      'LAN destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.InternetDestination), 'Internet destination');
  CheckEquals(Self.VpnIP,      Self.RT.LocalAddressFor(Self.VpnDestination),      'VPN destination');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForMultipleLansPlusMultipleMappedRoutes;
const
  SecondLanDestination = '172.0.0.2';
  SecondLanGateway     = '172.0.0.1';
  SecondLanIP          = '172.0.0.6';
  SecondLanMask        = '255.0.0.0';
  SecondLanRoute       = '172.0.0.0';
begin
  // Scenario: A machine with a LAN IP, and both a gateway to the internet and
  // a gateway to another network. (This is the situation for the author.)
  // The default route will use the LAN IP.
  Self.AddLoopbackRoute;
  Self.AddLanRoute;
  Self.RT.AddOsRoute(SecondLanRoute, SecondLanGateway, SecondLanMask, 1, '1', SecondLanIP);
  Self.AddDefaultRoute(Self.InternetGateway, Self.LanIP);

  Self.RT.AddMappedRoute(Self.InternetRoute, Self.InternetMask, Self.InternetIP);
  Self.RT.AddMappedRoute(Self.VpnRoute, Self.VpnMask, Self.VpnIP);

  CheckEquals(Self.LoopbackIP, Self.RT.LocalAddressFor(Self.LoopbackDestination), 'Local destination');
  CheckEquals(Self.LanIP,      Self.RT.LocalAddressFor(Self.LanDestination),      'LAN destination');
  CheckEquals(SecondLanIP,     Self.RT.LocalAddressFor(SecondLanDestination),     'LAN #2 destination');
  CheckEquals(Self.InternetIP, Self.RT.LocalAddressFor(Self.InternetDestination), 'Internet destination');
  CheckEquals(Self.VpnIP,      Self.RT.LocalAddressFor(Self.VpnDestination),      'VPN destination');
end;

procedure TestTIdIPv4RoutingTable.TestLocalAddressForNoRoutes;
begin
  CheckEquals('', Self.RT.LocalAddressFor(Self.LanDestination), 'LAN destination, no routes');
end;

procedure TestTIdIPv4RoutingTable.TestRemoveRoute;
begin
  // Make sure that RouteA <> RouteB.
  Self.RouteB.Destination := TIdIPAddressParser.IncIPAddress(Self.RouteB.Destination);
  Check(not Self.RouteA.Equals(Self.RouteB), 'Sanity check');

  Self.RT.AddMappedRoute(Self.RouteA.Destination, Self.RouteA.Mask, Self.RouteA.Gateway);
  Self.RT.AddMappedRoute(Self.RouteB.Destination, Self.RouteB.Mask, Self.RouteB.Gateway);
  Self.RT.RemoveRoute(Self.RouteA.Destination, Self.RouteA.Mask, Self.RouteA.Gateway);

  CheckEquals(1, Self.RT.RouteCount, 'Route not removed');
  Check(not Self.RT.HasRoute(Self.RouteA), 'Wrong route removed');
  Check(    Self.RT.HasRoute(Self.RouteB), 'Wrong route left in the table');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortDestinationAndMaskDiffers;
begin
  // "Higher" addresses appear earlier in the sorted routing table.

  Self.RouteA.Destination := '10.0.0.0';
  Self.RouteA.Mask        := '255.0.0.0';
  Self.RouteB.Destination := '192.168.0.0';
  Self.RouteB.Mask        := '255.255.255.0';

  CheckEquals(1,  RouteSort(Self.RouteA, Self.RouteB), '10.0.0.0/8 > 192.168.0.0/24');
  CheckEquals(-1, RouteSort(Self.RouteB, Self.RouteA), '192.168.0.0/24 > 10.0.0.0/8');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortGatewayAndMetricDiffers;
var
  PrimaryGateway, SecondaryGateway: TIdRouteEntry;
begin
  PrimaryGateway   := Self.RouteA;
  SecondaryGateway := Self.RouteB;

  // SecondaryGateway.Gateway < PrimaryGateway.Gateway, but
  // PrimaryGateway.Metric < SecondaryGateway.Metric. Metric takes priority.
  PrimaryGateway.Gateway   := '10.0.0.2';
  PrimaryGateway.Metric    := 1;
  SecondaryGateway.Gateway := '10.0.0.1';
  SecondaryGateway.Metric  := 2;

  CheckEquals(-1, RouteSort(PrimaryGateway, SecondaryGateway), 'PrimaryGateway < SecondaryGateway');
  CheckEquals(1,  RouteSort(SecondaryGateway, PrimaryGateway), 'SecondaryGateway > PrimaryGateway');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortIPv4RoutesFirst;
var
  IPv4Route, IPv6Route: TIdRouteEntry;
begin
  IPv4Route := Self.RouteA;
  IPv6Route := Self.RouteB;

  IPv4Route.Destination := '0.0.0.0';
  IPv4Route.Mask        := '0.0.0.0';
  IPv6Route.Destination := '::';
  IPv6Route.Mask        := '::';

  CheckEquals(-1, RouteSort(IPv4Route, IPv6Route), 'IPv4Route < IPv6Route');
  CheckEquals(1,  RouteSort(IPv6Route, IPv4Route), 'IPv6Route > IPv4Route');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortMetricDiffers;
begin
  // Even though RouteB's a "wider" route, it costs less
  Self.RouteA.Destination := '10.0.0.0';
  Self.RouteA.Mask        := '255.255.255.0';
  Self.RouteA.Metric      := 2;
  Self.RouteB.Destination := '10.0.0.0';
  Self.RouteB.Mask        := '255.0.0.0';
  Self.RouteB.Metric      := 1;

  CheckEquals(-1, RouteSort(Self.RouteA, Self.RouteB), 'RouteB < RouteA');
  CheckEquals(1,  RouteSort(Self.RouteB, Self.RouteA), 'RouteA < RouteB');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortOneRouteAMappedRoute;
var
  MappedRoute: TIdRouteEntry;
  NormalRoute: TIdRouteEntry;
begin
  NormalRoute := Self.RouteA;
  MappedRoute := Self.RouteB;

  MappedRoute.Gateway       := '1.2.3.4';
  MappedRoute.IsMappedRoute := true;

  CheckEquals(-1, RouteSort(MappedRoute, NormalRoute), 'All else being equal, MappedRoute < NormalRoute');
  CheckEquals(1,  RouteSort(NormalRoute, MappedRoute), 'All else being equal, NormalRoute > MappedRoute');

  MappedRoute.Metric := 999;
  CheckEquals(-1, RouteSort(MappedRoute, NormalRoute), 'MappedRoute < NormalRoute even when much more costly');
  CheckEquals(1,  RouteSort(NormalRoute, MappedRoute), 'NormalRoute > MappedRoute even when much less costly');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortOnlyDestinationDiffers;
var
  LowerAddress, HigherAddress: TIdRouteEntry;
begin
  // "Higher" addresses appear earlier in the sorted routing table.

  LowerAddress  := Self.RouteA;
  HigherAddress := Self.RouteB;

  LowerAddress.Destination  := '10.0.0.0';
  HigherAddress.Destination := '172.0.0.0';

  CheckEquals(1,  RouteSort(LowerAddress, HigherAddress), '10.0.0.0/8 < 172.0.0.0/8');
  CheckEquals(-1, RouteSort(HigherAddress, LowerAddress), '172.0.0.0/8 > 10.0.0.0/8');

  LowerAddress.Destination  := '0.0.0.0';
  HigherAddress.Destination := '172.0.0.0';

  CheckEquals(1,  RouteSort(LowerAddress, HigherAddress), '0.0.0.0/8 < 172.0.0.0/8');
  CheckEquals(-1, RouteSort(HigherAddress, LowerAddress), '172.0.0.0/8 > 0.0.0.0/8');

  LowerAddress.Destination  := '::';
  HigherAddress.Destination := '2002:0101:0101::';

  CheckEquals(1,  RouteSort(LowerAddress, HigherAddress), '::/8 < 2002:0101:0101::/8');
  CheckEquals(-1, RouteSort(HigherAddress, LowerAddress), '2002:0101:0101::/8 > ::/8');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortOnlyGatewayDiffers;
begin
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortOnlyMaskDiffers;
var
  NarrowerRoute, WiderRoute: TIdRouteEntry;
begin
  NarrowerRoute := Self.RouteA;
  WiderRoute    := Self.RouteB;

  WiderRoute.Destination    := '10.0.0.0';
  WiderRoute.Mask           := '255.0.0.0';
  NarrowerRoute.Destination := '10.0.0.0';
  NarrowerRoute.Mask        := '255.255.255.0';

  CheckEquals(-1, RouteSort(NarrowerRoute, WiderRoute), '10.0.0.0/24 < 10.0.0.0/8');
  CheckEquals(1,  RouteSort(WiderRoute, NarrowerRoute), '10.0.0.0/8 > 10.0.0.0/24');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortOnlyMetricDiffers;
var
  CheapRoute, ExpensiveRoute: TIdRouteEntry;
begin
  CheapRoute     := Self.RouteA;
  ExpensiveRoute := Self.RouteB;

  ExpensiveRoute.Metric := CheapRoute.Metric + 1;

  CheckEquals(-1, RouteSort(CheapRoute, ExpensiveRoute), 'CheapRoute < ExpensiveRoute');
  CheckEquals(1,  RouteSort(ExpensiveRoute, CheapRoute), 'ExpensiveRoute > CheapRoute');
end;

procedure TestTIdIPv4RoutingTable.TestRouteSortSameRoute;
begin
  CheckEquals(0, RouteSort(Self.RouteA, Self.RouteB), 'RouteA < RouteB');
  CheckEquals(0, RouteSort(Self.RouteB, Self.RouteA), 'RouteB > RouteA');
end;

initialization
  RegisterTest('Routing table functions', Suite);
end.