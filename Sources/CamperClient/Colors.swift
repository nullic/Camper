import Camper
import SwiftUI

let colorInt: Color = #hexColor(0xFF0000FF)
let colorString: Color = #hexColor("#00ffff")

#if canImport(UIKit)
    import UIKit

    let uiColorInt: UIColor = #hexUIColor(0xFF0000FF)
    let uiColorString: UIColor = #hexUIColor("#00ffff")
    let uiColorDynamic: UIColor = #hexUIColor("#eeffff", "#ffaaff")
#endif

#if canImport(AppKit)
    import AppKit

    let nsColorInt: NSColor = #hexNSColor(0xFF0000FF)
    let nsColorString: NSColor = #hexNSColor("#00ffff")
    let nsColorDynamic: NSColor = #hexNSColor("#eeffff", "#ffaaff")
#endif

func checkColors() {
    print("\(colorInt)")
    print("\(colorString)")

    #if canImport(UIKit)
        print("\(uiColorInt)")
        print("\(uiColorString)")
    #endif

    #if canImport(AppKit)
        print("\(nsColorInt)")
        print("\(nsColorString)")
        print("\(nsColorDynamic)")
    #endif
}
