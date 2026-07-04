// Minimal i18n: two flat maps (en/fr), looked up by key.
// Usage: AppStrings.of(context).t('drops_tab_title')
// or, without context: AppStrings.instance.t('drops_tab_title')
enum AppLocale { en, fr }

class AppStrings {
  static final AppStrings instance = AppStrings._internal();
  factory AppStrings() => instance;
  AppStrings._internal();

  AppLocale locale = AppLocale.fr; // default to French per user preference

  static const Map<String, String> _en = {
    'nav_drops': 'Drops',
    'nav_settings': 'Settings',
    'title_drop_campaigns': 'Drop campaigns',
    'title_settings': 'Settings',
    'title_filters': 'Filters & priority',
    'auto_mining': 'Auto-mining',
    'manual_mining': 'Manual mining',
    'linked_only': 'Linked only',
    'tap_to_switch': 'Tap a campaign below to switch what you mine.',
    'tap_to_start': 'Tap a campaign below to start mining it.',
    'no_campaigns_title': 'No campaigns to show',
    'no_campaigns_body':
        'Try turning off "Linked only", or check the debug logs (bug icon, top right) to see what Twitch returned.',
    'check_again': 'Check again',
    'retry': 'Retry',
    'failed_to_load': 'Failed to load campaigns',
    'refresh_campaigns': 'Refresh campaigns',
    'debug_logs': 'Debug logs',
    'filters': 'Filters',
    'sort_by': 'Sort by',
    'sort_expiring_soon': 'Expiring soonest first',
    'sort_most_viewers': 'Most viewers first',
    'sort_alphabetical': 'Alphabetical',
    'excluded_games': 'Excluded games',
    'excluded_games_hint': 'These games will never be auto-mined.',
    'priority_order': 'Priority order',
    'priority_hint': 'Drag to reorder — top games are mined first.',
    'language': 'Language',
    'connected_account': 'Connected account',
    'token_stored': 'Token stored',
    'not_connected': 'Not connected',
    'disconnect': 'Disconnect',
    'disconnect_confirm_title': 'Disconnect?',
    'disconnect_confirm_body':
        'This will remove your stored token. You will need to log in again.',
    'cancel': 'Cancel',
    'behavior': 'Behavior',
    'start_with_system': 'Start with system',
    'start_with_system_sub': 'Launch automatically at login',
    'minimize_to_tray': 'Minimize to tray on close',
    'minimize_to_tray_sub': 'Keep mining in background when window is closed',
    'about': 'About',
    'source_code': 'Source code',
  };

  static const Map<String, String> _fr = {
    'nav_drops': 'Drops',
    'nav_settings': 'Réglages',
    'title_drop_campaigns': 'Campagnes de drops',
    'title_settings': 'Réglages',
    'title_filters': 'Filtres et priorités',
    'auto_mining': 'Minage auto',
    'manual_mining': 'Minage manuel',
    'linked_only': 'Comptes liés',
    'tap_to_switch': 'Touchez une campagne pour changer ce que vous minez.',
    'tap_to_start': 'Touchez une campagne pour commencer à la miner.',
    'no_campaigns_title': 'Aucune campagne à afficher',
    'no_campaigns_body':
        'Essayez de désactiver "Comptes liés", ou consultez les logs de debug (icône bug, en haut à droite) pour voir la réponse de Twitch.',
    'check_again': 'Vérifier à nouveau',
    'retry': 'Réessayer',
    'failed_to_load': 'Échec du chargement des campagnes',
    'refresh_campaigns': 'Actualiser les campagnes',
    'debug_logs': 'Logs de debug',
    'filters': 'Filtres',
    'sort_by': 'Trier par',
    'sort_expiring_soon': "Expiration la plus proche d'abord",
    'sort_most_viewers': "Le plus de viewers d'abord",
    'sort_alphabetical': 'Ordre alphabétique',
    'excluded_games': 'Jeux exclus',
    'excluded_games_hint': 'Ces jeux ne seront jamais minés automatiquement.',
    'priority_order': 'Ordre de priorité',
    'priority_hint':
        "Glissez pour réorganiser — les jeux en haut sont minés en premier.",
    'language': 'Langue',
    'connected_account': 'Compte connecté',
    'token_stored': 'Jeton enregistré',
    'not_connected': 'Non connecté',
    'disconnect': 'Se déconnecter',
    'disconnect_confirm_title': 'Se déconnecter ?',
    'disconnect_confirm_body':
        'Cela supprimera votre jeton enregistré. Vous devrez vous reconnecter.',
    'cancel': 'Annuler',
    'behavior': 'Comportement',
    'start_with_system': 'Démarrer avec le système',
    'start_with_system_sub': 'Lancer automatiquement à la connexion',
    'minimize_to_tray': 'Réduire dans la barre système à la fermeture',
    'minimize_to_tray_sub':
        "Continuer à miner en arrière-plan quand la fenêtre est fermée",
    'about': 'À propos',
    'source_code': 'Code source',
  };

  String t(String key) {
    final map = locale == AppLocale.fr ? _fr : _en;
    return map[key] ?? _en[key] ?? key;
  }
}

// Shorthand global accessor: tr('key')
String tr(String key) => AppStrings.instance.t(key);
