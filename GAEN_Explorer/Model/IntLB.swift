//
//  IntegerLowerBound.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/13/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Foundation

struct IntLB: Equatable, ExpressibleByIntegerLiteral, CustomStringConvertible, Codable, Hashable, LosslessStringConvertible {
    init?(_ description: String) {
        if description.hasPrefix(">= ") {
            self.isExact = true
            let suffix: String = String(description.suffix(3))
            value = Int(suffix) ?? 0
        } else {
            self.isExact = false
            self.value = Int(description) ?? 0
        }
    }

    static let unknown = IntLB(0, false)
    let value: Int
    let isExact: Bool
    init(exact: Int) {
        self.value = exact
        self.isExact = true
    }

    init(integerLiteral value: IntegerLiteralType) {
        self.value = value
        self.isExact = value < 30
    }

    init(_ value: Int) {
        self.value = value
        self.isExact = value < 30
    }

    init(_ value: Int, _ isExact: Bool) {
        self.value = value
        self.isExact = isExact
    }

    var description: String {
        if isExact {
            return "\(value)"
        }
        return ">= \(value)"
    }

    var isZero: Bool {
        value == 0 && isExact
    }

    func asLowerBound() -> IntLB {
        if isExact {
            return IntLB(value, false)
        }
        return self
    }

    func applyLowerBound(_ lb: Int) -> IntLB {
        if isExact {
            assert(value >= lb, "Bug")
            return self
        }
        return IntLB(max(value, lb), false)
    }

    func applyLowerBound(_ lb: IntLB?) -> IntLB {
        if let lowerBound = lb {
            return applyLowerBound(lowerBound.value)
        }
        return self
    }

    func intersection(_ rhs: IntLB) -> IntLB {
        switch (isExact, rhs.isExact) {
        case (false, false):
            return IntLB(max(value, rhs.value))
        case (true, false):
            if value < rhs.value {
                print("Intersection \(self), \(rhs): must have grown")
                return rhs
            }
            assert(value >= rhs.value, "Bug")
            return self
        case (false, true):
            if value > rhs.value {
                print("Intersection \(self), \(rhs): must have grown")
                return self
            }
            assert(value <= rhs.value, "Bug")
            return rhs
        case (true, true):
            if value != rhs.value {
                print("Intersection \(self), \(rhs): must have grown")
                return IntLB(max(value, rhs.value), true)
            }
            assert(value == rhs.value, "Bug")
            return self
        }
    }
}

func + (lhs: IntLB, rhs: IntLB) -> IntLB {
    IntLB(lhs.value + rhs.value, lhs.isExact && rhs.isExact)
}

func minus(_ lhs: IntLB, _ rhs: IntLB) -> IntLB {
    if rhs.isExact {
        return IntLB(lhs.value - rhs.value, lhs.isExact)
    }
    return IntLB.unknown
}

func - (lhs: IntLB, rhs: IntLB) -> IntLB {
    if rhs.isExact {
        return IntLB(lhs.value - rhs.value, lhs.isExact)
    }
    return IntLB.unknown
}

func / (lhs: IntLB, rhs: Int) -> IntLB {
    IntLB(lhs.value / rhs, lhs.isExact)
}

func == (lhs: IntLB, rhs: Int) -> Bool {
    lhs.value == rhs && lhs.isExact
}

func > (lhs: IntLB, rhs: Int) -> Bool {
    lhs.value > rhs || lhs.isExact
}

func intersection(_ lhs: IntLB, _ rhs: IntLB) -> IntLB {
    switch (lhs.isExact, rhs.isExact) {
    case (false, false):
        return IntLB(max(lhs.value, rhs.value))
    case (true, false):
        assert(lhs.value >= rhs.value, "Bug")
        return lhs
    case (false, true):
        assert(lhs.value <= rhs.value, "Bug")
        return rhs
    case (true, true):
        assert(lhs.value == rhs.value, "Bug")
        return lhs
    }
}
