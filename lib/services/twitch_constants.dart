// Twitch internal API constants. Subject to change if Twitch updates their client.
class TwitchConstants {
  static const String gqlUrl = 'https://gql.twitch.tv/gql';
  static const String clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko'; // public web client id, used for GQL once logged in
  static const String deviceClientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp'; // android client, supports device code grant
  static const String deviceCodeUrl = 'https://id.twitch.tv/oauth2/device';
  static const String tokenUrl = 'https://id.twitch.tv/oauth2/token';
  static const String wsUrl = 'wss://pubsub-edge.twitch.tv/v1';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36';
}
