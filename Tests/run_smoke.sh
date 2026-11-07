#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swiftc EdenDriveIQ/OfferParser.swift EdenDriveIQ/Profitability.swift Tests/SmokeMain.swift -o /tmp/edendrive-iq-smoke
/tmp/edendrive-iq-smoke Fixtures/uber_offer.txt
