//
//  IntegerLowerBound.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/13/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Foundation

struct BoundedInt: Equatable, ExpressibleByIntegerLiteral, CustomStringConvertible, Codable, Hashable, LosslessStringConvertible {
    init?(_: String) {
        assert(false)
        self.preciseLB = 0
        self.ub = BoundedInt.infinity
    }

    static let Zero = BoundedInt(0, 0)
    static let unknown = BoundedInt(0, BoundedInt.infinity)
    static let infinity = 999

    static func rounded(_ v: Int) -> Int {
        if v == 0 || v == BoundedInt.infinity {
            return v
        }
        return v + 2
    }

    static func unrounded(_ v: Int) -> Int {
        if v == 0 || v == BoundedInt.infinity {
            return v
        }

        return max(1, v - 2)
    }

    let preciseLB: Int
    var lb: Int {
        min(BoundedInt.rounded(preciseLB), ub)
    }

    let ub: Int

    var isNearlyExact: Bool {
        ub != BoundedInt.infinity && BoundedInt.rounded(preciseLB) == BoundedInt.rounded(ub)
    }

    var isLowerBound: Bool {
        ub == BoundedInt.infinity
    }

    var isUnknown: Bool {
        lb == 0 && ub == BoundedInt.infinity
    }

    init(precise: Int) {
        self.preciseLB = precise
        self.ub = precise
    }

    init(uncapped: Int) {
        self.preciseLB = BoundedInt.unrounded(uncapped)
        self.ub = uncapped
    }

    init(integerLiteral value: IntegerLiteralType) {
        self.preciseLB = BoundedInt.unrounded(value)
        if value >= 30 {
            self.ub = BoundedInt.infinity
        } else {
            self.ub = value
        }
    }

    init(_ value: Int) {
        self.preciseLB = BoundedInt.unrounded(value)
        if value >= 30 {
            self.ub = BoundedInt.infinity
        } else {
            self.ub = value
        }
    }

    init(_ lb: Int, _ ub: Int) {
        assert(lb <= ub)
        self.preciseLB = lb
        self.ub = ub
    }

    init(lb: Int) {
        self.preciseLB = lb
        self.ub = BoundedInt.infinity
    }

    var description: String {
        if isLowerBound {
            return "\(preciseLB)+"
        }
        if isNearlyExact {
            return "\(ub)"
        }

        return "\(preciseLB)...\(ub)"
    }

    func matches(_ value: Int) -> Bool {
        preciseLB <= value && value <= ub
    }

    func matches(_ value: BoundedInt) -> Bool {
        preciseLB <= value.lb && value.ub <= ub
    }

    func asLowerBound() -> BoundedInt {
        if isLowerBound {
            return self
        }
        return BoundedInt(preciseLB, BoundedInt.infinity)
    }

    func applyBounds(lb: BoundedInt = BoundedInt.unknown, ub: BoundedInt = BoundedInt.unknown) -> BoundedInt {
        let newMax = min(self.ub, ub.ub)
        let newMin = max(lb.preciseLB, preciseLB)
        if newMin > newMax {
            print("must have grown \(lb) <= \(self) <= \(ub)")
            if preciseLB <= newMin {
                return BoundedInt(newMin, newMin)
            } else if newMax <= self.ub {
                return BoundedInt(newMax, self.ub)
            }
            return self
        }
        return BoundedInt(newMin, newMax)
    }

    func softApplyBounds(lb: BoundedInt, ub: BoundedInt) -> BoundedInt {
        let newMax = min(self.ub, ub.ub)
        let newMin = max(lb.preciseLB, preciseLB)
        if newMin > newMax {
            return self
        }
        return BoundedInt(newMin, newMax)
    }

    //    func applyBounds(_ lb: BoundedInt?) -> BoundedInt {
    //        if let lowerBound = lb {
    //            return applyBounds(lowerBound.value)
    //        }
    //        return self
    //    }

    func minimum(_ rhs: BoundedInt) -> BoundedInt {
        let ub = min(self.ub, rhs.ub)
        let lb = max(preciseLB, rhs.preciseLB)
        if lb <= ub {
            return BoundedInt(lb, ub)
        }
        if self.ub < rhs.ub {
            return self
        }
        return rhs
    }

    func intersection(_ rhsMaybe: BoundedInt?) -> BoundedInt {
        guard let rhs = rhsMaybe else {
            return self
        }
        let lb = max(preciseLB, rhs.preciseLB)
        let ub = min(self.ub, rhs.ub)
        if lb > ub {
            if rhs.isLowerBound {
                let result = BoundedInt(rhs.preciseLB, rhs.preciseLB)
                print("1 Must have grown \(self) & \(rhs) -> \(result)")
                return result
            }
            if isLowerBound {
                let result = BoundedInt(lb, lb)
                print("2 Must have grown \(self) & \(rhs) -> \(result)")
                return result
            }
            let result = BoundedInt(lb, max(self.ub, rhs.ub))
            print("3 Must have grown \(self) & \(rhs) -> \(result)")
            print(Thread.callStackSymbols[1])
            return result
        }
        return BoundedInt(lb, ub)
    }

    func intersectionMaybe(_ rhsMaybe: BoundedInt?) -> BoundedInt {
        guard let rhs = rhsMaybe else {
            return self
        }
        let lb = max(preciseLB, rhs.preciseLB)
        let ub = min(self.ub, rhs.ub)
        if lb > ub {
            print("4 Must have grown \(self) & \(rhs) -> \(self)")
            return self
        }
        return BoundedInt(lb, ub)
    }
}

func + (lhs: BoundedInt, rhs: BoundedInt) -> BoundedInt {
    if lhs.isLowerBound || rhs.isLowerBound {
        return BoundedInt(lhs.preciseLB + rhs.preciseLB, BoundedInt.infinity)
    }
    return BoundedInt(lhs.preciseLB + rhs.preciseLB, lhs.ub + rhs.ub)
}

func minus(_ lhs: BoundedInt, _ rhs: BoundedInt) -> BoundedInt {
    lhs - rhs
}

func - (lhs: BoundedInt, rhs: BoundedInt) -> BoundedInt {
    if rhs.isLowerBound {
        return BoundedInt.unknown
    }
    if lhs.isLowerBound {
        return BoundedInt(lb: max(0, lhs.preciseLB - rhs.ub))
    }
    return BoundedInt(max(0, lhs.preciseLB - rhs.ub), max(0, lhs.ub - rhs.preciseLB))
}

func / (lhs: BoundedInt, rhs: Int) -> BoundedInt {
    if lhs.isLowerBound {
        return BoundedInt(lb: lhs.preciseLB / rhs)
    }
    return BoundedInt(lhs.preciseLB / rhs, lhs.ub / rhs)
}

func == (lhs: BoundedInt, rhs: Int) -> Bool {
    lhs.isNearlyExact && lhs.ub == rhs
}

func == (lhs: BoundedInt, rhs: BoundedInt) -> Bool {
    lhs.lb == rhs.lb && lhs.ub == rhs.ub
}

func > (lhs: BoundedInt, rhs: Int) -> Bool {
    lhs.preciseLB > rhs
}

func intersection(_ lhs: BoundedInt, _ rhs: BoundedInt?) -> BoundedInt {
    lhs.intersection(rhs)
}
