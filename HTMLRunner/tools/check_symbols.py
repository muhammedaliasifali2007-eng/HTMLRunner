#!/usr/bin/env python3
"""
Catches the bug class that broke the first real build:
a reference to a type name that no longer exists ("cannot find 'X' in scope").

How: collect every type this project declares, collect every identifier that is
*used* like a type (constructors `Name(` and annotations `: Name`, `[Name]`,
`Name.` members), subtract the declarations and a whitelist of Apple SDK types,
and report whatever is left over for review.

Exit code 1 if anything suspicious is found.
"""

import glob
import os
import re
import sys

ROOT = "/home/user/HTMLRunner"

DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public\s+|private\s+|fileprivate\s+|internal\s+|final\s+|open\s+|@objc\s+)*"
    r"(?:struct|class|enum|protocol|actor|extension)\s+([A-Z][A-Za-z0-9_]*)",
    re.MULTILINE,
)

# Apple frameworks used by this project (types + a few protocols).
SDK = set("""
View Text Image Button Label Link NavigationStack NavigationLink ScrollView LazyVGrid GridItem
ForEach VStack HStack ZStack Group Form Section TextField TextEditor TabView List Menu Spacer
ToolbarItem ToolbarItemGroup ToolbarContent ToolbarContentBuilder ContentUnavailableView
ShareLink EditButton Spacer Divider ProgressView Toggle Picker DatePicker Stepper
Color RoundedRectangle Rectangle Capsule Circle LinearGradient Font ShapeStyle
Environment EnvironmentObject State StateObject Binding Published ObservableObject ObservedObject
MainActor Task Actor AnyView ViewBuilder PreviewProvider Identifiable Hashable Codable
Date UUID URL URLRequest URLComponents URLQueryItem URLSession JSONEncoder JSONDecoder
Data String Substring Character Int Double Bool CGFloat CGFloat Array Dictionary Set Optional
Result Error Timer Calendar Locale Bundle ProcessInfo Notification NotificationCenter
FileManager UserDefaults NSObject NSError NSItemProvider NSExtensionItem NSSecureCoding
DispatchQueue DispatchTime DispatchGroup
WKWebView WKWebViewConfiguration WKNavigationDelegate WKNavigationAction WKNavigationActionPolicy
UIViewRepresentable UIView UIViewController UIResponder UIApplication UIPasteboard UIColor UIImage
UIButton UILabel UIImageView UIActivityIndicatorView UIStackView UIFont UIButtonConfiguration
UIScrollView UITableView UIFeedbackGenerator NSLayoutConstraint
UTType CharacterSet IndexSet Range ClosedRange CaseIterable Equatable Comparable Sequence
App Scene WindowGroup Context LabeledContent NSSelectorFromString UTF8 CodeContent
Collection IteratorProtocol ExpressibleByStringLiteral CustomStringConvertible
""".split())

USAGE_PATTERNS = [
    re.compile(r"(?<![.\w])([A-Z][A-Za-z0-9_]*)\((?![^)]*\)\s*(?:->|throws))"),  # Name(
    re.compile(r":\s*\[?([A-Z][A-Za-z0-9_]*)\]?(?![A-Za-z0-9_])"),                 # : Type
    re.compile(r"\[([A-Z][A-Za-z0-9_]*)\]"),                                        # [Type]
]


def main():
    files = sorted(
        glob.glob(os.path.join(ROOT, "HTMLRunner", "*.swift"))
        + glob.glob(os.path.join(ROOT, "ShareExtension", "*.swift"))
        + glob.glob(os.path.join(ROOT, "Shared", "*.swift"))
    )
    if not files:
        print("no Swift files found"); return 1

    declarations = {}
    for path in files:
        text = open(path).read()
        for name in DECL.findall(text):
            declarations.setdefault(name, os.path.basename(path))

    print(f"declared types ({len(declarations)}):")
    for name, where in sorted(declarations.items()):
        print(f"  {name:28s} {where}")

    unknown = {}
    for path in files:
        text = open(path).read()
        # ignore comments and string literals to avoid false positives
        text = re.sub(r"//[^\n]*", "", text)
        text = re.sub(r'"""(?:.|\n)*?"""', '""', text)
        text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
        for pattern in USAGE_PATTERNS:
            for name in pattern.findall(text):
                if name in declarations or name in SDK:
                    continue
                unknown.setdefault(name, set()).add(os.path.basename(path))

    print()
    if unknown:
        print("⚠ identifiers used like types but never declared here and not known SDK types:")
        for name, where in sorted(unknown.items()):
            print(f"  {name:28s} used in: {', '.join(sorted(where))}")
        print("\nReview these: a renamed/removed type shows up here as a build error.")
        return 1

    print("✓ every type reference resolves to a project declaration or an Apple SDK type")
    return 0


if __name__ == "__main__":
    sys.exit(main())
