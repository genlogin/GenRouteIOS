import SwiftUI

enum AppString {
    static let splashTitle: LocalizedStringKey = "splash_title"
    
    // Language Screen
    static let languageSelect: LocalizedStringKey = "language_select"
    static let languageEnglishContinue: LocalizedStringKey = "language_english_continue"
    
    // Onboarding Screen
    static let onboardingTitle: LocalizedStringKey = "onboarding_title"
    static let onboardingDesc: LocalizedStringKey = "onboarding_desc"
    static let onboardingButton: LocalizedStringKey = "onboarding_button"
    
    // Home Screen
    static let homeMapBase: LocalizedStringKey = "home_map_base"
    // Home Tabs
    static let tabRide: LocalizedStringKey = "tab_ride"
    static let tabJourneys: LocalizedStringKey = "tab_journeys"
    static let tabSettings: LocalizedStringKey = "tab_settings"
    
    // Map Editor
    static let mapEditorSave: LocalizedStringKey = "map_editor_save"
    static let mapEditorSearch: LocalizedStringKey = "map_editor_search"
    static let mapEditorNoResults: LocalizedStringKey = "map_editor_no_results"
    static let mapEditorSearchPrompt: LocalizedStringKey = "map_editor_search_prompt"
    static let mapEditorDismiss: LocalizedStringKey = "map_editor_dismiss"
    static let mapEditorSaveTitle: LocalizedStringKey = "map_editor_save_title"
    static let mapEditorSaveName: LocalizedStringKey = "map_editor_save_name"
    static let mapEditorSaveDesc: LocalizedStringKey = "map_editor_save_desc"

    // Ride Page
    static let rideEmptyTitle: LocalizedStringKey = "ride_empty_title"
    static let rideFavoritePlaces: LocalizedStringKey = "ride_favorite_places"
    static let rideAddPlace: LocalizedStringKey = "ride_add_place"
    static let ridePermissionTitle: LocalizedStringKey = "ride_permission_title"
    static let ridePermissionDesc: LocalizedStringKey = "ride_permission_desc"
    static let rideCancel: LocalizedStringKey = "ride_cancel"
    static let rideDelete: LocalizedStringKey = "ride_delete"
    static let rideOk: LocalizedStringKey = "ride_ok"
    static let ridePlaceLatLngFormat: LocalizedStringKey = "ride_place_lat_lng_format"
    
    // Ride Dialogs
    static let rideEditTitle: LocalizedStringKey = "ride_edit_title"
    static let rideEditSave: LocalizedStringKey = "ride_edit_save"
    static let rideDeleteConfirmTitle: LocalizedStringKey = "ride_delete_confirm_title"
    static let rideDeleteConfirmDesc: LocalizedStringKey = "ride_delete_confirm_desc"

    // Directions
    static let directionsTitle: LocalizedStringKey = "directions_title"
    static let directionsRouteErrorTitle: LocalizedStringKey = "directions_route_error_title"
    static let directionsStartSection: LocalizedStringKey = "directions_start_section"
    static let directionsEndSection: LocalizedStringKey = "directions_end_section"
    static let directionsSummaryEstLabel: LocalizedStringKey = "directions_summary_est_label"
    static let rideDirectionsNeedTwoPlacesTitle: LocalizedStringKey = "ride_directions_need_two_places_title"
    static let rideDirectionsNeedTwoPlacesMessage: LocalizedStringKey = "ride_directions_need_two_places_message"
    static let directionsSettingsTitle: LocalizedStringKey = "directions_settings_title"
    static let directionsFocusStartHint: LocalizedStringKey = "directions_focus_start_hint"
    static let directionsCompassNorthHint: LocalizedStringKey = "directions_compass_north_hint"
    static let directionsStartTripButton: LocalizedStringKey = "directions_start_trip_button"
    static let directionsDevPanelTitle: LocalizedStringKey = "directions_dev_panel_title"
    static let directionsDevSpeedLabel: LocalizedStringKey = "directions_dev_speed_label"
    static let directionsNavPuckA11y: LocalizedStringKey = "directions_nav_puck_a11y"
    static let directionsNextManeuverTitle: LocalizedStringKey = "directions_next_maneuver_title"
    static let directionsToNextManeuver: LocalizedStringKey = "directions_to_next_maneuver"
    static let directionsStopButton: LocalizedStringKey = "directions_stop_button"
    static let directionsStopA11y: LocalizedStringKey = "directions_stop_a11y"
    static let directionsStopConfirmTitle: LocalizedStringKey = "directions_stop_confirm_title"
    static let directionsStopConfirmMessage: LocalizedStringKey = "directions_stop_confirm_message"
    static let directionsStopConfirmAction: LocalizedStringKey = "directions_stop_confirm_action"
    static let directionsArrivalTitle: LocalizedStringKey = "directions_arrival_title"
    static let directionsArrivalMessage: LocalizedStringKey = "directions_arrival_message"
    static let directionsViewTripResults: LocalizedStringKey = "directions_view_trip_results"
    static let directionsMinimapA11y: LocalizedStringKey = "directions_minimap_a11y"

    // Trip result
    static let tripResultTitle: LocalizedStringKey = "trip_result_title"
    static let tripResultRecordName: LocalizedStringKey = "trip_result_record_name"
    static let tripResultCompletedAt: LocalizedStringKey = "trip_result_completed_at"
    static let tripResultStartToDestination: LocalizedStringKey = "trip_result_start_to_destination"
    static let tripResultDistanceTraveled: LocalizedStringKey = "trip_result_distance_traveled"
    static let tripResultAvgSpeed: LocalizedStringKey = "trip_result_avg_speed"
    static let tripResultMaxSpeed: LocalizedStringKey = "trip_result_max_speed"
    static let tripResultMovingTime: LocalizedStringKey = "trip_result_moving_time"
    static let tripResultElapsedTime: LocalizedStringKey = "trip_result_elapsed_time"
    static let tripResultDistance: LocalizedStringKey = "trip_result_distance"
    static let tripResultRateRoutePrompt: LocalizedStringKey = "trip_result_rate_route_prompt"
    static let tripResultDone: LocalizedStringKey = "trip_result_done"
    static let tripResultMapStart: LocalizedStringKey = "trip_result_map_start"
    static let tripResultMapEnd: LocalizedStringKey = "trip_result_map_end"
    static let directionsContinueRouteFallback: LocalizedStringKey = "directions_continue_route_fallback"
    static let directionsVehicleSection: LocalizedStringKey = "directions_vehicle_section"
    static let directionsVehicleTypeLabel: LocalizedStringKey = "directions_vehicle_type_label"
    static let directionsVehicleBicycle: LocalizedStringKey = "directions_vehicle_bicycle"
    static let directionsVehicleMotorcycle: LocalizedStringKey = "directions_vehicle_motorcycle"
    static let directionsAvoidSection: LocalizedStringKey = "directions_avoid_section"
    static let directionsAvoidHighway: LocalizedStringKey = "directions_avoid_highway"
    static let directionsAvoidToll: LocalizedStringKey = "directions_avoid_toll"
    static let directionsAvoidFerry: LocalizedStringKey = "directions_avoid_ferry"
    static let directionsAvoidPoorRoad: LocalizedStringKey = "directions_avoid_poor_road"
    static let directionsSettingsApply: LocalizedStringKey = "directions_settings_apply"
    static let directionsSettingsCancel: LocalizedStringKey = "directions_settings_cancel"
    static let directionsSettingsFooterNote: LocalizedStringKey = "directions_settings_footer_note"

    // Journeys Page
    static let journeyEmptyList: LocalizedStringKey = "journey_empty_list"

    // Settings Page
    static let settingsSectionAccount: LocalizedStringKey = "settings_section_account"
    static let settingsProfile: LocalizedStringKey = "settings_profile"
    static let settingsSectionPreferences: LocalizedStringKey = "settings_section_preferences"
    static let settingsNotifications: LocalizedStringKey = "settings_notifications"
    static let settingsLanguage: LocalizedStringKey = "settings_language"

    // Generic / Fallback
    static let unknownLocation: LocalizedStringKey = "unknown_location"
    static let unknownShort: LocalizedStringKey = "unknown_short"
}
