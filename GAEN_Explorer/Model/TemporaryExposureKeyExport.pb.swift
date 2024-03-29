// DO NOT EDIT.
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: TemporaryExposureKeyExport.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
private struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
    struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
    typealias Version = _2
}

struct TemporaryExposureKeyExport {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Time window of keys in the file, based on arrival
    /// at the server, in UTC seconds.
    var startTimestamp: UInt64 {
        get { _startTimestamp ?? 0 }
        set { _startTimestamp = newValue }
    }

    /// Returns true if `startTimestamp` has been explicitly set.
    var hasStartTimestamp: Bool { self._startTimestamp != nil }
    /// Clears the value of `startTimestamp`. Subsequent reads from it will return its default value.
    mutating func clearStartTimestamp() { _startTimestamp = nil }

    var endTimestamp: UInt64 {
        get { _endTimestamp ?? 0 }
        set { _endTimestamp = newValue }
    }

    /// Returns true if `endTimestamp` has been explicitly set.
    var hasEndTimestamp: Bool { self._endTimestamp != nil }
    /// Clears the value of `endTimestamp`. Subsequent reads from it will return its default value.
    mutating func clearEndTimestamp() { _endTimestamp = nil }

    /// The region from which these keys came
    var region: String {
        get { _region ?? String() }
        set { _region = newValue }
    }

    /// Returns true if `region` has been explicitly set.
    var hasRegion: Bool { self._region != nil }
    /// Clears the value of `region`. Subsequent reads from it will return its default value.
    mutating func clearRegion() { _region = nil }

    /// Reserved for future use. Both batch_num and batch_size
    /// must be set to a value of 1.
    var batchNum: Int32 {
        get { _batchNum ?? 0 }
        set { _batchNum = newValue }
    }

    /// Returns true if `batchNum` has been explicitly set.
    var hasBatchNum: Bool { self._batchNum != nil }
    /// Clears the value of `batchNum`. Subsequent reads from it will return its default value.
    mutating func clearBatchNum() { _batchNum = nil }

    var batchSize: Int32 {
        get { _batchSize ?? 0 }
        set { _batchSize = newValue }
    }

    /// Returns true if `batchSize` has been explicitly set.
    var hasBatchSize: Bool { self._batchSize != nil }
    /// Clears the value of `batchSize`. Subsequent reads from it will return its default value.
    mutating func clearBatchSize() { _batchSize = nil }

    /// Information about associated signatures
    var signatureInfos: [SignatureInfo] = []

    /// Exposure keys that are new.
    var keys: [TemporaryExposureKey] = []

    /// Keys that have changed status from previous key archives,
    /// including keys that are being revoked.
    var revisedKeys: [TemporaryExposureKey] = []

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    private var _startTimestamp: UInt64?
    private var _endTimestamp: UInt64?
    private var _region: String?
    fileprivate var _batchNum: Int32?
    fileprivate var _batchSize: Int32?
}

struct SignatureInfo {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Key version in case the key server signing key is rotated. (e.g. "v1")
    /// A PHA can only have one active public key at a time, so they must rotate
    /// keys on all devices and servers at the same time to avoid problems.
    var verificationKeyVersion: String {
        get { _verificationKeyVersion ?? String() }
        set { _verificationKeyVersion = newValue }
    }

    /// Returns true if `verificationKeyVersion` has been explicitly set.
    var hasVerificationKeyVersion: Bool { self._verificationKeyVersion != nil }
    /// Clears the value of `verificationKeyVersion`. Subsequent reads from it will return its default value.
    mutating func clearVerificationKeyVersion() { _verificationKeyVersion = nil }

    /// Implementation-specific string that can be used in key verification.
    /// Valid character in this string are all alphanumeric characters,
    /// underscores, and periods.
    var verificationKeyID: String {
        get { _verificationKeyID ?? String() }
        set { _verificationKeyID = newValue }
    }

    /// Returns true if `verificationKeyID` has been explicitly set.
    var hasVerificationKeyID: Bool { self._verificationKeyID != nil }
    /// Clears the value of `verificationKeyID`. Subsequent reads from it will return its default value.
    mutating func clearVerificationKeyID() { _verificationKeyID = nil }

    /// All keys must be signed using the SHA-256 with ECDSA algorithm.
    /// This field must contain the string "1.2.840.10045.4.3.2".
    var signatureAlgorithm: String {
        get { _signatureAlgorithm ?? String() }
        set { _signatureAlgorithm = newValue }
    }

    /// Returns true if `signatureAlgorithm` has been explicitly set.
    var hasSignatureAlgorithm: Bool { self._signatureAlgorithm != nil }
    /// Clears the value of `signatureAlgorithm`. Subsequent reads from it will return its default value.
    mutating func clearSignatureAlgorithm() { _signatureAlgorithm = nil }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _verificationKeyVersion: String?
    fileprivate var _verificationKeyID: String?
    fileprivate var _signatureAlgorithm: String?
}

struct TemporaryExposureKey {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Temporary exposure key for an infected user.
    var keyData: Data {
        get { _keyData ?? SwiftProtobuf.Internal.emptyData }
        set { _keyData = newValue }
    }

    /// Returns true if `keyData` has been explicitly set.
    var hasKeyData: Bool { self._keyData != nil }
    /// Clears the value of `keyData`. Subsequent reads from it will return its default value.
    mutating func clearKeyData() { _keyData = nil }

    /// Varying risk associated with a key depending on diagnosis method.
    /// Deprecated and no longer used.
    var transmissionRiskLevel: Int32 {
        get { _transmissionRiskLevel ?? 0 }
        set { _transmissionRiskLevel = newValue }
    }

    /// Returns true if `transmissionRiskLevel` has been explicitly set.
    var hasTransmissionRiskLevel: Bool { self._transmissionRiskLevel != nil }
    /// Clears the value of `transmissionRiskLevel`. Subsequent reads from it will return its default value.
    mutating func clearTransmissionRiskLevel() { _transmissionRiskLevel = nil }

    /// The interval number since epoch for which a key starts
    var rollingStartIntervalNumber: Int32 {
        get { _rollingStartIntervalNumber ?? 0 }
        set { _rollingStartIntervalNumber = newValue }
    }

    /// Returns true if `rollingStartIntervalNumber` has been explicitly set.
    var hasRollingStartIntervalNumber: Bool { self._rollingStartIntervalNumber != nil }
    /// Clears the value of `rollingStartIntervalNumber`. Subsequent reads from it will return its default value.
    mutating func clearRollingStartIntervalNumber() { _rollingStartIntervalNumber = nil }

    /// How long this key is valid, specified in increments of 10 minutes
    var rollingPeriod: Int32 {
        get { _rollingPeriod ?? 144 }
        set { _rollingPeriod = newValue }
    }

    /// Returns true if `rollingPeriod` has been explicitly set.
    var hasRollingPeriod: Bool { self._rollingPeriod != nil }
    /// Clears the value of `rollingPeriod`. Subsequent reads from it will return its default value.
    mutating func clearRollingPeriod() { _rollingPeriod = nil }

    /// Type of diagnosis associated with a key.
    var reportType: TemporaryExposureKey.ReportType {
        get { _reportType ?? .unknown }
        set { _reportType = newValue }
    }

    /// Returns true if `reportType` has been explicitly set.
    var hasReportType: Bool { self._reportType != nil }
    /// Clears the value of `reportType`. Subsequent reads from it will return its default value.
    mutating func clearReportType() { _reportType = nil }

    /// Number of days elapsed between symptom onset and the TEK being used.
    /// E.g. 2 means TEK is from 2 days after onset of symptoms.
    /// Valid values range is from -14 to 14.
    var daysSinceOnsetOfSymptoms: Int32 {
        get { _daysSinceOnsetOfSymptoms ?? 0 }
        set { _daysSinceOnsetOfSymptoms = newValue }
    }

    /// Returns true if `daysSinceOnsetOfSymptoms` has been explicitly set.
    var hasDaysSinceOnsetOfSymptoms: Bool { self._daysSinceOnsetOfSymptoms != nil }
    /// Clears the value of `daysSinceOnsetOfSymptoms`. Subsequent reads from it will return its default value.
    mutating func clearDaysSinceOnsetOfSymptoms() { _daysSinceOnsetOfSymptoms = nil }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    /// Data type that represents why this key was published.
    enum ReportType: SwiftProtobuf.Enum {
        typealias RawValue = Int

        /// Never returned by the client API.
        case unknown // = 0
        case confirmedTest // = 1
        case confirmedClinicalDiagnosis // = 2
        case selfReport // = 3

        /// Reserved for future use.
        case recursive // = 4

        /// Used to revoke a key, never returned by client API.
        case revoked // = 5

        init() {
            self = .unknown
        }

        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .unknown
            case 1: self = .confirmedTest
            case 2: self = .confirmedClinicalDiagnosis
            case 3: self = .selfReport
            case 4: self = .recursive
            case 5: self = .revoked
            default: return nil
            }
        }

        var rawValue: Int {
            switch self {
            case .unknown: return 0
            case .confirmedTest: return 1
            case .confirmedClinicalDiagnosis: return 2
            case .selfReport: return 3
            case .recursive: return 4
            case .revoked: return 5
            }
        }
    }

    init() {}

    private var _keyData: Data?
    private var _transmissionRiskLevel: Int32?
    private var _rollingStartIntervalNumber: Int32?
    private var _rollingPeriod: Int32?
    private var _reportType: TemporaryExposureKey.ReportType?
    private var _daysSinceOnsetOfSymptoms: Int32?
}

#if swift(>=4.2)

    extension TemporaryExposureKey.ReportType: CaseIterable {
        // Support synthesized by the compiler.
    }

#endif // swift(>=4.2)

struct TEKSignatureList {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Information about associated signatures
    var signatures: [TEKSignature] = []

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

struct TEKSignature {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Information to uniquely identify the public key associated
    /// with the key server's signing key.
    var signatureInfo: SignatureInfo {
        get { _signatureInfo ?? SignatureInfo() }
        set { _signatureInfo = newValue }
    }

    /// Returns true if `signatureInfo` has been explicitly set.
    var hasSignatureInfo: Bool { self._signatureInfo != nil }
    /// Clears the value of `signatureInfo`. Subsequent reads from it will return its default value.
    mutating func clearSignatureInfo() { _signatureInfo = nil }

    /// Reserved for future use. Both batch_num and batch_size
    /// must be set to a value of 1.
    var batchNum: Int32 {
        get { _batchNum ?? 0 }
        set { _batchNum = newValue }
    }

    /// Returns true if `batchNum` has been explicitly set.
    var hasBatchNum: Bool { self._batchNum != nil }
    /// Clears the value of `batchNum`. Subsequent reads from it will return its default value.
    mutating func clearBatchNum() { _batchNum = nil }

    var batchSize: Int32 {
        get { _batchSize ?? 0 }
        set { _batchSize = newValue }
    }

    /// Returns true if `batchSize` has been explicitly set.
    var hasBatchSize: Bool { self._batchSize != nil }
    /// Clears the value of `batchSize`. Subsequent reads from it will return its default value.
    mutating func clearBatchSize() { _batchSize = nil }

    /// Signature in X9.62 format (ASN.1 SEQUENCE of two INTEGER fields).
    var signature: Data {
        get { _signature ?? SwiftProtobuf.Internal.emptyData }
        set { _signature = newValue }
    }

    /// Returns true if `signature` has been explicitly set.
    var hasSignature: Bool { self._signature != nil }
    /// Clears the value of `signature`. Subsequent reads from it will return its default value.
    mutating func clearSignature() { _signature = nil }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    private var _signatureInfo: SignatureInfo?
    fileprivate var _batchNum: Int32?
    fileprivate var _batchSize: Int32?
    private var _signature: Data?
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension TemporaryExposureKeyExport: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "TemporaryExposureKeyExport"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "start_timestamp"),
        2: .standard(proto: "end_timestamp"),
        3: .same(proto: "region"),
        4: .standard(proto: "batch_num"),
        5: .standard(proto: "batch_size"),
        6: .standard(proto: "signature_infos"),
        7: .same(proto: "keys"),
        8: .standard(proto: "revised_keys"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularFixed64Field(value: &_startTimestamp)
            case 2: try decoder.decodeSingularFixed64Field(value: &_endTimestamp)
            case 3: try decoder.decodeSingularStringField(value: &_region)
            case 4: try decoder.decodeSingularInt32Field(value: &_batchNum)
            case 5: try decoder.decodeSingularInt32Field(value: &_batchSize)
            case 6: try decoder.decodeRepeatedMessageField(value: &signatureInfos)
            case 7: try decoder.decodeRepeatedMessageField(value: &keys)
            case 8: try decoder.decodeRepeatedMessageField(value: &revisedKeys)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = _startTimestamp {
            try visitor.visitSingularFixed64Field(value: v, fieldNumber: 1)
        }
        if let v = _endTimestamp {
            try visitor.visitSingularFixed64Field(value: v, fieldNumber: 2)
        }
        if let v = _region {
            try visitor.visitSingularStringField(value: v, fieldNumber: 3)
        }
        if let v = _batchNum {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 4)
        }
        if let v = _batchSize {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 5)
        }
        if !signatureInfos.isEmpty {
            try visitor.visitRepeatedMessageField(value: signatureInfos, fieldNumber: 6)
        }
        if !keys.isEmpty {
            try visitor.visitRepeatedMessageField(value: keys, fieldNumber: 7)
        }
        if !revisedKeys.isEmpty {
            try visitor.visitRepeatedMessageField(value: revisedKeys, fieldNumber: 8)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TemporaryExposureKeyExport, rhs: TemporaryExposureKeyExport) -> Bool {
        if lhs._startTimestamp != rhs._startTimestamp { return false }
        if lhs._endTimestamp != rhs._endTimestamp { return false }
        if lhs._region != rhs._region { return false }
        if lhs._batchNum != rhs._batchNum { return false }
        if lhs._batchSize != rhs._batchSize { return false }
        if lhs.signatureInfos != rhs.signatureInfos { return false }
        if lhs.keys != rhs.keys { return false }
        if lhs.revisedKeys != rhs.revisedKeys { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension SignatureInfo: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "SignatureInfo"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        3: .standard(proto: "verification_key_version"),
        4: .standard(proto: "verification_key_id"),
        5: .standard(proto: "signature_algorithm"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 3: try decoder.decodeSingularStringField(value: &_verificationKeyVersion)
            case 4: try decoder.decodeSingularStringField(value: &_verificationKeyID)
            case 5: try decoder.decodeSingularStringField(value: &_signatureAlgorithm)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = _verificationKeyVersion {
            try visitor.visitSingularStringField(value: v, fieldNumber: 3)
        }
        if let v = _verificationKeyID {
            try visitor.visitSingularStringField(value: v, fieldNumber: 4)
        }
        if let v = _signatureAlgorithm {
            try visitor.visitSingularStringField(value: v, fieldNumber: 5)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: SignatureInfo, rhs: SignatureInfo) -> Bool {
        if lhs._verificationKeyVersion != rhs._verificationKeyVersion { return false }
        if lhs._verificationKeyID != rhs._verificationKeyID { return false }
        if lhs._signatureAlgorithm != rhs._signatureAlgorithm { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension TemporaryExposureKey: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "TemporaryExposureKey"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "key_data"),
        2: .standard(proto: "transmission_risk_level"),
        3: .standard(proto: "rolling_start_interval_number"),
        4: .standard(proto: "rolling_period"),
        5: .standard(proto: "report_type"),
        6: .standard(proto: "days_since_onset_of_symptoms"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularBytesField(value: &_keyData)
            case 2: try decoder.decodeSingularInt32Field(value: &_transmissionRiskLevel)
            case 3: try decoder.decodeSingularInt32Field(value: &_rollingStartIntervalNumber)
            case 4: try decoder.decodeSingularInt32Field(value: &_rollingPeriod)
            case 5: try decoder.decodeSingularEnumField(value: &_reportType)
            case 6: try decoder.decodeSingularSInt32Field(value: &_daysSinceOnsetOfSymptoms)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = _keyData {
            try visitor.visitSingularBytesField(value: v, fieldNumber: 1)
        }
        if let v = _transmissionRiskLevel {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 2)
        }
        if let v = _rollingStartIntervalNumber {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 3)
        }
        if let v = _rollingPeriod {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 4)
        }
        if let v = _reportType {
            try visitor.visitSingularEnumField(value: v, fieldNumber: 5)
        }
        if let v = _daysSinceOnsetOfSymptoms {
            try visitor.visitSingularSInt32Field(value: v, fieldNumber: 6)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TemporaryExposureKey, rhs: TemporaryExposureKey) -> Bool {
        if lhs._keyData != rhs._keyData { return false }
        if lhs._transmissionRiskLevel != rhs._transmissionRiskLevel { return false }
        if lhs._rollingStartIntervalNumber != rhs._rollingStartIntervalNumber { return false }
        if lhs._rollingPeriod != rhs._rollingPeriod { return false }
        if lhs._reportType != rhs._reportType { return false }
        if lhs._daysSinceOnsetOfSymptoms != rhs._daysSinceOnsetOfSymptoms { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension TemporaryExposureKey.ReportType: SwiftProtobuf._ProtoNameProviding {
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        0: .same(proto: "UNKNOWN"),
        1: .same(proto: "CONFIRMED_TEST"),
        2: .same(proto: "CONFIRMED_CLINICAL_DIAGNOSIS"),
        3: .same(proto: "SELF_REPORT"),
        4: .same(proto: "RECURSIVE"),
        5: .same(proto: "REVOKED"),
    ]
}

extension TEKSignatureList: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "TEKSignatureList"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "signatures"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &signatures)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !signatures.isEmpty {
            try visitor.visitRepeatedMessageField(value: signatures, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TEKSignatureList, rhs: TEKSignatureList) -> Bool {
        if lhs.signatures != rhs.signatures { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension TEKSignature: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "TEKSignature"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "signature_info"),
        2: .standard(proto: "batch_num"),
        3: .standard(proto: "batch_size"),
        4: .same(proto: "signature"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularMessageField(value: &_signatureInfo)
            case 2: try decoder.decodeSingularInt32Field(value: &_batchNum)
            case 3: try decoder.decodeSingularInt32Field(value: &_batchSize)
            case 4: try decoder.decodeSingularBytesField(value: &_signature)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let v = _signatureInfo {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
        }
        if let v = _batchNum {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 2)
        }
        if let v = _batchSize {
            try visitor.visitSingularInt32Field(value: v, fieldNumber: 3)
        }
        if let v = _signature {
            try visitor.visitSingularBytesField(value: v, fieldNumber: 4)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: TEKSignature, rhs: TEKSignature) -> Bool {
        if lhs._signatureInfo != rhs._signatureInfo { return false }
        if lhs._batchNum != rhs._batchNum { return false }
        if lhs._batchSize != rhs._batchSize { return false }
        if lhs._signature != rhs._signature { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
