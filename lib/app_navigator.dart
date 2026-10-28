import 'package:flutter/widgets.dart';

/// Az app gyökér-navigátora: így értesítésből vagy háttéreseményből (pl. bump) is
/// megnyitható egy képernyő.
final appNavigatorKey = GlobalKey<NavigatorState>();
