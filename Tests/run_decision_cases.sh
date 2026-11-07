#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swiftc EdenDriveIQ/OfferParser.swift EdenDriveIQ/Profitability.swift Tests/DecisionCases.swift -o /tmp/edendrive-iq-cases
/tmp/edendrive-iq-cases
