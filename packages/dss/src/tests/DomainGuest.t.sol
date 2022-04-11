// SPDX-License-Identifier: AGPL-3.0-or-later

/// DomainJoin.sol -- xdomain join adapter

// Copyright (C) 2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.13;

import "dss-test/DSSTest.sol";

import { DaiJoinMock } from "./mocks/DaiJoinMock.sol";
import { DaiMock } from "./mocks/DaiMock.sol";
import { EndMock } from "./mocks/EndMock.sol";
import { EscrowMock } from "./mocks/EscrowMock.sol";
import { VatMock } from "./mocks/VatMock.sol";
import { DomainGuest } from "../DomainGuest.sol";

contract EmptyDomainGuest is DomainGuest {

    uint256 public releaseBurned;
    uint256 public surplus;
    uint256 public deficit;

    constructor(address _daiJoin) DomainGuest(_daiJoin) {}

    function _release(uint256 burned) internal override {
        releaseBurned = burned;
    }
    function _surplus(uint256 wad) internal virtual override {
        surplus = wad;
    }
    function _deficit(uint256 wad) internal virtual override {
       deficit = wad;
    }

}

contract DomainGuestTest is DSSTest {

    VatMock vat;
    DaiJoinMock daiJoin;
    DaiMock dai;
    EndMock end;

    EmptyDomainGuest guest;

    function postSetup() internal virtual override {
        vat = new VatMock();
        dai = new DaiMock();
        daiJoin = new DaiJoinMock(address(vat), address(dai));
        end = new EndMock();

        guest = new EmptyDomainGuest(address(daiJoin));
        guest.file("end", address(end));
    }

    function _tryRely(address usr) internal returns (bool ok) {
        (ok,) = address(guest).call(abi.encodeWithSignature("rely(address)", usr));
    }

    function _tryDeny(address usr) internal returns (bool ok) {
        (ok,) = address(guest).call(abi.encodeWithSignature("deny(address)", usr));
    }

    function _tryFile(bytes32 what, address data) internal returns (bool ok) {
        (ok,) = address(guest).call(abi.encodeWithSignature("file(bytes32,address)", what, data));
    }

    function testConstructor() public {
        assertEq(address(guest.vat()), address(vat));
        assertEq(address(guest.daiJoin()), address(daiJoin));
        assertEq(address(guest.dai()), address(dai));
        assertEq(guest.wards(address(this)), 1);
    }

    function testRelyDeny() public {
        assertEq(guest.wards(address(456)), 0);
        assertTrue(_tryRely(address(456)));
        assertEq(guest.wards(address(456)), 1);
        assertTrue(_tryDeny(address(456)));
        assertEq(guest.wards(address(456)), 0);

        guest.deny(address(this));

        assertTrue(!_tryRely(address(456)));
        assertTrue(!_tryDeny(address(456)));
    }

    function testFile() public {
        assertEq(address(guest.end()), address(end));
        assertTrue(_tryFile("end", address(888)));
        assertEq(address(guest.end()), address(888));

        guest.deny(address(this));

        assertTrue(!_tryFile("end", address(888)));
    }

    function testInvalidWhat() public {
       assertTrue(!_tryFile("meh", address(888)));
    }

}
