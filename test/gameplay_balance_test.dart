import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:void_protocol/game/components/asteroid.dart';
import 'package:void_protocol/game/components/cryo_pod.dart';
import 'package:void_protocol/game/components/enemy_ship.dart';
import 'package:void_protocol/game/components/player.dart';
import 'package:void_protocol/game/components/xp_orb.dart';
import 'package:void_protocol/game/weapons.dart';
import 'package:void_protocol/game/asteroids_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Asteroid Inverted Scoring Tests', () {
    test(
      'Small asteroids score 300 pts, medium score 150 pts, large score 50 pts',
      () {
        final smallAsteroid = AsteroidComponent(
          radius: 20.0,
          position: Vector2.zero(),
          velocity: Vector2.zero(),
        );
        final mediumAsteroid = AsteroidComponent(
          radius: 35.0,
          position: Vector2.zero(),
          velocity: Vector2.zero(),
        );
        final largeAsteroid = AsteroidComponent(
          radius: 60.0,
          position: Vector2.zero(),
          velocity: Vector2.zero(),
        );

        expect(
          smallAsteroid.scoreValue,
          equals(300),
          reason: 'Small asteroids must reward highest points (+300)',
        );
        expect(
          mediumAsteroid.scoreValue,
          equals(150),
          reason: 'Medium asteroids reward intermediate points (+150)',
        );
        expect(
          largeAsteroid.scoreValue,
          equals(50),
          reason: 'Large asteroids reward opening points (+50)',
        );
      },
    );
  });

  group('Weapon Balance and Evolution Tests', () {
    test('All 4 weapons start at level 1 and upgrade properly to level 5', () {
      final blaster = Blaster();
      final spread = SpreadShot();
      final rapid = RapidFire();
      final bomb = BombLauncher();

      // Check initial level 1 stats
      expect(blaster.level, equals(1));
      expect(blaster.maxLevel, equals(5));
      expect(blaster.damage, equals(26.0));
      expect(blaster.cooldown, equals(0.70));

      expect(spread.level, equals(1));
      expect(spread.damage, equals(14.0));
      expect(spread.cooldown, equals(0.95));
      expect(spread.recoil, equals(14.0));

      expect(rapid.level, equals(1));
      expect(rapid.cooldown, equals(0.32));
      expect(rapid.damage, equals(10.0));

      expect(bomb.level, equals(1));
      expect(bomb.damage, equals(80.0));
      expect(bomb.cooldown, equals(1.80));
      expect(bomb.recoil, equals(22.0));

      // Test Upgrade to Level 2
      expect(blaster.upgrade(), isTrue);
      expect(spread.upgrade(), isTrue);
      expect(rapid.upgrade(), isTrue);
      expect(bomb.upgrade(), isTrue);

      expect(blaster.level, equals(2));
      expect(blaster.damage, equals(34.0));
      expect(spread.level, equals(2));
      expect(spread.damage, equals(18.0));
      expect(rapid.level, equals(2));
      expect(rapid.damage, equals(13.0));
      expect(bomb.level, equals(2));
      expect(bomb.damage, equals(105.0));

      // Upgrade through Level 3, 4 to Level 5 (Max)
      for (var i = 0; i < 3; i++) {
        expect(blaster.upgrade(), isTrue);
        expect(spread.upgrade(), isTrue);
        expect(rapid.upgrade(), isTrue);
        expect(bomb.upgrade(), isTrue);
      }

      expect(blaster.level, equals(5));
      expect(spread.level, equals(5));
      expect(rapid.level, equals(5));
      expect(bomb.level, equals(5));

      // Cannot upgrade beyond max
      expect(blaster.upgrade(), isFalse);
    });

    test(
      'Weapons DO NOT upgrade automatically by time or score; progression is purely roguelike',
      () {
        final game = AsteroidsGame();
        game.player = PlayerComponent(position: Vector2.zero());
        game.state = GameState.playing;
        final startingWeapon = game.player.weapon;
        expect(startingWeapon.level, equals(1));

        // Destroy asteroids pushing score beyond 1200 and 3000
        game.onAsteroidDestroyed(Vector2.zero(), 1500);
        expect(game.score, equals(1500));
        expect(
          game.player.weapon.level,
          equals(1),
          reason: 'Weapon must NOT auto-upgrade at 1200 points',
        );

        game.onAsteroidDestroyed(Vector2.zero(), 2000);
        expect(game.score, equals(3500));
        expect(
          game.player.weapon.level,
          equals(1),
          reason: 'Weapon must NOT auto-upgrade at 3000 points',
        );
      },
    );
  });

  group('Progression & Difficulty Separation Tests', () {
    test('Normal mode vs Hyper / Void Cells difficulty multipliers scale cleanly', () {
      final game = AsteroidsGame();
      game.isHyperMode = false;
      game.voidCellsLevel = 0;

      expect(game.isHardDifficulty, isFalse);
      expect(game.incomingDamageMultiplier, equals(1.0));
      expect(game.effectiveSpawnPaceMultiplier, equals(1.0));

      game.isHyperMode = true;
      expect(game.isHardDifficulty, isTrue);
      expect(game.incomingDamageMultiplier, greaterThan(1.2));
      expect(game.effectiveSpawnPaceMultiplier, greaterThan(1.2));

      game.voidCellsLevel = 3;
      expect(game.incomingDamageMultiplier, greaterThan(1.7));
      expect(game.effectiveSpawnPaceMultiplier, greaterThan(1.5));

      expect(EnemyShipComponent.baseContactDamage(EnemyType.scout), lessThanOrEqualTo(12.0));
      expect(EnemyShipComponent.baseContactDamage(EnemyType.eliteCommander), lessThanOrEqualTo(30.0));

      final vanguardElite = EnemyShipComponent(
        position: Vector2.zero(),
        type: EnemyType.eliteCommander,
        hpMultiplier: 0.55,
      );
      expect(vanguardElite.maxHp, closeTo(650.0 * 0.55, 0.01));
    });

    test('XP curve & rewards stay smooth without runaway multi-level spikes', () {
      expect(AsteroidsGame.calculateNextLevelXp(1), equals(30));
      expect(AsteroidsGame.calculateNextLevelXp(2), equals(76));
      expect(AsteroidsGame.calculateNextLevelXp(3), equals(134));
      expect(AsteroidsGame.calculateNextLevelXp(4), equals(222));
      expect(AsteroidsGame.calculateNextLevelXp(5), equals(330));

      final game = AsteroidsGame();
      game.player = PlayerComponent(position: Vector2.zero())..customGame = game;
      game.state = GameState.playing;

      // Golden asteroid yields 2 large XP orbs (28 XP), not a massive 70 XP spike
      final golden = AsteroidComponent(
        radius: 35.0,
        position: Vector2(200, 200),
        velocity: Vector2.zero(),
        variant: AsteroidVariant.golden,
      )..game = game;
      golden.split();
      final goldenOrbs = game.world.children.whereType<XpOrbComponent>().toList();
      expect(goldenOrbs.length, equals(2));

      // CryoPod awards balanced +140 XP instead of 500 XP cascade
      final pod = CryoPodComponent(position: Vector2(10, 10))..game = game;
      pod.salvage();
      expect(game.runLevel, lessThanOrEqualTo(3));
    });
  });
}
