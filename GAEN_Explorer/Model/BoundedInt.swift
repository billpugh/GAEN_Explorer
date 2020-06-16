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
        self.lb = 0
        self.ub = BoundedInt.infinity
    }

    static let unknown = BoundedInt(0, BoundedInt.infinity)
    static let infinity = 999
    let lb: Int
    let ub: Int
    var isExact: Bool {
        lb == ub
    }

    var isLowerBound: Bool {
        ub == BoundedInt.infinity
    }

    init(exact: Int) {
        self.lb = exact
        self.ub = exact
    }

    init(integerLiteral value: IntegerLiteralType) {
        self.lb = value
        self.ub = value < 30 ? value : BoundedInt.infinity
    }

    init(_ value: Int) {
        self.lb = value
        self.ub = value < 30 ? value : BoundedInt.infinity
    }

    init(_ lb: Int, _ ub: Int) {
        assert(lb <= ub)
        self.lb = lb
        self.ub = ub
    }

    init(lb: Int) {
        self.lb = lb
        self.ub = BoundedInt.infinity
    }

    var description: String {
        if isExact {
            return "\(lb)"
        }
        if isLowerBound {
            return "\(lb)+"
        }
        return "\(lb)...\(ub)"
    }

    var isZero: Bool {
        lb == 0 && isExact
    }

    func matches(_ value: Int) -> Bool {
        lb <= value && value <= ub
    }

    func asLowerBound() -> BoundedInt {
        if isLowerBound {
            return self
        }
        return BoundedInt(lb, BoundedInt.infinity)
    }

    func applyBounds(lb: BoundedInt, ub: BoundedInt) -> BoundedInt {
        let newMax = min(self.ub, ub.ub)
        let newMin = max(lb.lb, self.lb)
        if newMin > newMax {
            print("must have grown \(lb) <= \(self) <= \(ub)")
            if self.lb <= newMin {
                return BoundedInt(self.lb, newMin)
            } else if newMax <= self.ub {
                return BoundedInt(newMax, self.ub)
            }
            return self
        }
        return BoundedInt(newMin, newMax)
    }

    func softApplyBounds(lb: BoundedInt, ub: BoundedInt) -> BoundedInt {
        let newMax = min(self.ub, ub.ub)
        let newMin = max(lb.lb, self.lb)
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
        if self.lb > rhs.ub {
            print("Must have grown \(rhs)  -> \(self)")
            return self
        }
        if self.ub < rhs.lb {
            print("Must have grown \(self)  -> \(rhs)")
            return rhs
        }
        let lb = max(self.lb, rhs.lb)
        let ub = min(self.ub, rhs.ub)
        return BoundedInt(lb, ub)
    }

    func intersectionMaybe(_ rhs: BoundedInt) -> BoundedInt {
        if self.lb > rhs.ub {
            print("Must have grown \(rhs)  -> \(self)")
            return self
        }
        if self.ub < rhs.lb {
            print("rhs incompatible with \(self), ignoring \(rhs)")
            return self
        }
        let lb = max(self.lb, rhs.lb)
        let ub = min(self.ub, rhs.ub)
        return BoundedInt(lb, ub)
    }
}

func + (lhs: BoundedInt, rhs: BoundedInt) -> BoundedInt {
    if lhs.isLowerBound || rhs.isLowerBound {
        return BoundedInt(lhs.lb + rhs.lb, BoundedInt.infinity)
    }
    return BoundedInt(lhs.lb + rhs.lb, lhs.ub + rhs.ub)
}

func minus(_ lhs: BoundedInt, _ rhs: BoundedInt) -> BoundedInt {
    if rhs.isLowerBound {
        return BoundedInt.unknown
    }
    if lhs.isLowerBound {
        return BoundedInt(lb: lhs.lb - rhs.ub)
    }
    return BoundedInt(lhs.lb - rhs.ub, lhs.ub - rhs.lb)
}

func - (lhs: BoundedInt, rhs: BoundedInt) -> BoundedInt {
    if rhs.isLowerBound {
        return BoundedInt.unknown
    }
    if lhs.isLowerBound {
        return BoundedInt(lb: lhs.lb - rhs.ub)
    }
    return BoundedInt(lhs.lb - rhs.ub, lhs.ub - rhs.lb)
}

func / (lhs: BoundedInt, rhs: Int) -> BoundedInt {
    if lhs.isLowerBound {
        return BoundedInt(lb: lhs.lb / rhs)
    }
    return BoundedInt(lhs.lb / rhs, lhs.ub / rhs)
}

func == (lhs: BoundedInt, rhs: Int) -> Bool {
    lhs.lb == rhs && lhs.isExact
}

func > (lhs: BoundedInt, rhs: Int) -> Bool {
    lhs.lb > rhs
}

func intersection(_ lhs: BoundedInt, _ rhs: BoundedInt) -> BoundedInt {
    lhs.intersection(rhs)
}
