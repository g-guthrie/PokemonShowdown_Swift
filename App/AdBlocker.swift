import WebKit

/// Blocks the ad network Showdown loads (Venatus, `hb.vntsm.com`) and the ad exchanges
/// and trackers it pulls in. With the loader blocked, no ad slots are created.
enum AdBlocker {
    static let domains = [
        "vntsm.com", "doubleclick.net", "googlesyndication.com", "googletagservices.com", "googletagmanager.com",
        "google-analytics.com", "googleadservices.com", "adservice.google.com", "amazon-adsystem.com", "adnxs.com",
        "rubiconproject.com", "pubmatic.com", "openx.net", "criteo.com", "criteo.net", "casalemedia.com",
        "33across.com", "sharethrough.com", "indexww.com", "smartadserver.com", "teads.tv", "yieldmo.com",
        "media.net", "gumgum.com", "3lift.com", "adsrvr.org", "sonobi.com", "lijit.com", "onetag-sys.com",
        "id5-sync.com", "confiant-integrations.net", "btloader.com", "quantserve.com", "scorecardresearch.com",
        "adform.net", "seedtag.com", "ozoneproject.com", "tapad.com", "ipredictive.com", "bidswitch.net",
        "rlcdn.com", "crwdcntrl.net", "everesttech.net", "demdex.net", "adsafeprotected.com", "moatads.com",
        "doubleverify.com", "kargo.com", "richaudience.com", "connectad.io", "e-planning.net", "smilewanted.com",
    ]

    static var rulesJSON: String {
        let rules = domains.map { domain -> String in
            let escaped = domain.replacingOccurrences(of: ".", with: "\\\\.")
            return #"{"trigger":{"url-filter":"^[^:]+://+([^:/]+\\.)?\#(escaped)[:/]"},"action":{"type":"block"}}"#
        }
        return "[" + rules.joined(separator: ",") + "]"
    }

    static func load(_ completion: @escaping (WKContentRuleList?) -> Void) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "showdown-ads-v1",
            encodedContentRuleList: rulesJSON
        ) { list, _ in
            DispatchQueue.main.async { completion(list) }
        }
    }
}
