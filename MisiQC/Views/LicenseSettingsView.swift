import SwiftUI

/// Settings tab — shows the current status and lets the user paste & activate
/// a licence key bought on Payhip.
struct LicenseSettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    @State private var draftKey: String = ""
    @State private var activationMessage: String?
    @State private var activationIsError: Bool = false

    private let purchaseURL = URL(string: "https://payhip.com/b/NqSMZ")!

    var body: some View {
        Form {
            Section {
                statusRow
            } header: {
                Text(state.t(.licenseSectionStatus))
            }

            Section {
                HStack(alignment: .top, spacing: 8) {
                    TextField(state.t(.licenseEnterKeyPlaceholder),
                              text: $draftKey,
                              axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .font(.system(size: 11).monospaced())
                        .autocorrectionDisabled()
                    Button(state.t(.licenseActivateButton)) {
                        activate()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !draftKey.isEmpty {
                    let n = draftKey.uppercased().filter { Self.base32Chars.contains($0) }.count
                    Text("\(n) / \(LicenseError.expectedKeyLength)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(n == LicenseError.expectedKeyLength ? .green : .secondary)
                }
                if let msg = activationMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(activationIsError ? .red : .green)
                }
                Button {
                    openURL(purchaseURL)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill")
                        Text(state.t(.licenseBuyButton))
                    }
                }
                if case .licensed = state.license.status {
                    Button(role: .destructive) {
                        state.license.deactivate()
                        activationMessage = nil
                    } label: {
                        Label(state.t(.licenseDeactivateButton),
                              systemImage: "key.slash")
                    }
                }
            } header: {
                Text(state.t(.licenseSectionActivate))
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch state.license.status {
        case .trial(let days):
            statusLine(systemImage: "clock.fill",
                       tint: days <= 2 ? Brand.accentPeach : Brand.accentBlue,
                       text: String(format: state.t(.licenseStatusTrial), days))
        case .licensed(let expiry, _):
            let text: String = LicenseService.isPerpetual(expiry)
                ? String(format: state.t(.licenseStatusLifetime), state.license.hostName)
                : String(format: state.t(.licenseStatusLicensed),
                         Self.shortDate(expiry), state.license.hostName)
            statusLine(systemImage: "checkmark.seal.fill",
                       tint: Brand.accentMint,
                       text: text)
        case .expired:
            statusLine(systemImage: "exclamationmark.octagon.fill",
                       tint: Color(red: 0.85, green: 0.2, blue: 0.2),
                       text: state.t(.licenseStatusExpired))
        }
    }

    private func statusLine(systemImage: String, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func activate() {
        let result = state.license.activate(rawKey: draftKey)
        switch result {
        case .success(let expiry):
            activationIsError = false
            let dateOrLifetime: String = LicenseService.isPerpetual(expiry)
                ? state.t(.licenseExpiryLifetime)
                : Self.shortDate(expiry)
            activationMessage = String(format: state.t(.licenseActivatedMessage),
                                       dateOrLifetime)
            draftKey = ""
        case .failure(let err):
            activationIsError = true
            activationMessage = Self.localizedError(err, locale: state.locale)
        }
    }

    private static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    private static func localizedError(_ err: LicenseError, locale: AppLocale) -> String {
        switch err {
        case .malformedKey(let n):
            return String(format: L10n.t(.licenseErrorMalformed, locale),
                          n, LicenseError.expectedKeyLength)
        case .invalidSignature:    return L10n.t(.licenseErrorSignature, locale)
        case .keyExpired(let d):   return String(format: L10n.t(.licenseErrorExpired, locale),
                                                 shortDate(d))
        case .unsupportedVersion:  return L10n.t(.licenseErrorUnsupported, locale)
        }
    }

    private static let base32Chars: Set<Character> =
        Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
}
