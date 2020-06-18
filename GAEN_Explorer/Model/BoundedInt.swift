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

    static let unknown = BoundedInt(0, BoundedInt.infinity)
    static let infinity = 999

    static func rounded(_ v: Int) -> Int {
        if v == 0 || v == BoundedInt.infinity {
            return v
        }
        return (v + 4) / 5 * 5
    }

    static func unrounded(_ v: Int) -> Int {
        if v == 0 || v == BoundedInt.infinity {
            return v
        }
        assert(v % 5 == 0)
        return v - 4
    }

    let preciseLB: Int
    var lb: Int {
        BoundedInt.rounded(preciseLB)
    }

    let ub: Int

    var isNearlyExact: Bool {
        ub != BoundedInt.infinity && lb == BoundedInt.rounded(ub)
    }

    var isLowerBound: Bool {
        ub == BoundedInt.infinity
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
            return "\(lb)+"
        }
        if isNearlyExact {
            return "\(lb)"
        }

        return "\(lb)...\(BoundedInt.rounded(ub))"
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

    func applyBounds(lb: BoundedInt, ub: BoundedInt) -> BoundedInt {
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

    func checkIntersection(_ rhs: BoundedInt) {
        print("bad intersection \(self) \(rhs), must have grown")
    }

    func intersection(_ rhs: BoundedInt) -> BoundedInt {
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
            return result
        }
        return BoundedInt(lb, ub)
    }

    func intersectionMaybe(_ rhs: BoundedInt) -> BoundedInt {
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

func intersection(_ lhs: BoundedInt, _ rhs: BoundedInt) -> BoundedInt {
    lhs.intersection(rhs)
}
