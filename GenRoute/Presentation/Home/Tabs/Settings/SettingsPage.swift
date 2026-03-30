import SwiftUI

struct SettingsPage: View {
    @StateObject var viewModel: SettingsPageViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(AppString.settingsSectionAccount)) {
                    Text(AppString.settingsProfile)
                }
                Section(header: Text(AppString.settingsSectionPreferences)) {
                    Text(AppString.settingsNotifications)
                    Text(AppString.settingsLanguage)
                }
            }
            .navigationTitle(AppString.tabSettings)
        }
    }
}
