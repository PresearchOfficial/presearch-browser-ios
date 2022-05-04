// Copyright 2021 The Presearch Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

struct WalletConstants {
  /// The Presearch swap fee as a % value
  ///
  /// This value will be formatted to a string such as 0.875%)
  static let braveSwapFee: Double = 0.00875

  /// The wei value used for unlimited allowance in an ERC 20 transaction.
  static let MAX_UINT256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
}
