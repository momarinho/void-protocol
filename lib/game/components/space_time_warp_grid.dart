import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:void_protocol/constants.dart';
import 'package:void_protocol/game/asteroids_game.dart';
import 'package:void_protocol/game/components/enemy_ship.dart';
import 'package:void_protocol/game/components/singularity_vortex.dart';

/// Ponto de coordenadas da grade espacial com suporte a distorção gravitacional
class WarpGridPoint {
  double worldX = 0.0;
  double worldY = 0.0;
  double warpedX = 0.0;
  double warpedY = 0.0;
}

/// SPRINT 56: Deformação de Grade Gravitacional (Space-Time Warp Grid)
/// Linhas de coordenadas cósmicas sutis desenhadas no espaço que se curvam
/// e dobram dinamicamente em direção a corpos de alta massa gravitacional:
/// buracos negros (SingularityVortex / SingularityRift), asteroides colossais
/// e chefes titânicos (simulação de curvatura do espaço-tempo da Relatividade Geral).
///
/// Arquitetura Zero-GC: Grade matricial pré-alocada de 20x14 nós reaproveitada
/// a cada quadro, zero Paint ou Path instanciados em render().
class SpaceTimeWarpGridComponent extends Component
    with HasGameReference<AsteroidsGame> {
  static const double gridCellSize = 140.0;
  static const int cols = 18; // Cobre 18 * 140 = 2520px de largura
  static const int rows = 12; // Cobre 12 * 140 = 1680px de altura (inclui Portrait mobile)

  // Matriz pré-alocada de nós de coordenadas
  late final List<List<WarpGridPoint>> _gridNodes;

  // Zero-GC Cached Paints, Path & Wells buffer
  static final Paint _gridLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _gravityNodePaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  static final Path _gridPath = Path();
  final List<({double x, double y, double radius, double strength})>
  _gravityWells = [];

  SpaceTimeWarpGridComponent() {
    priority =
        -30; // Renderiza logo atrás de naves e projéteis (0+) e acima do pó estelar (-35)
    _initGrid();
  }

  void _initGrid() {
    _gridNodes = List.generate(
      rows,
      (_) => List.generate(cols, (_) => WarpGridPoint()),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    Vector2 camPos;
    try {
      camPos = game.camera.viewfinder.position;
    } catch (_) {
      camPos = Vector2(
        GameConstants.sectorWidth / 2,
        GameConstants.sectorHeight / 2,
      );
    }

    final width = game.visibleWorldWidth;
    final height = game.visibleWorldHeight;

    final viewLeft = camPos.x - width / 2;
    final viewTop = camPos.y - height / 2;

    // Alinhamento dos nós da grade ao módulo do mundo para scrolling contínuo
    final startWorldX =
        (viewLeft / gridCellSize).floor() * gridCellSize - gridCellSize * 2;
    final startWorldY =
        (viewTop / gridCellSize).floor() * gridCellSize - gridCellSize * 2;

    // 1. Coleta fontes ativas de gravidade próximas à tela (Zero-GC buffer)
    _gravityWells.clear();
    final gravityWells = _gravityWells;

    try {
      // Buracos negros / vórtices de singularidade
      for (final child in game.world.children) {
        if (child is SingularityVortexComponent) {
          final dx = (child.position.x - camPos.x).abs();
          final dy = (child.position.y - camPos.y).abs();
          if (dx < width * 0.9 && dy < height * 0.9) {
            gravityWells.add((
              x: child.position.x,
              y: child.position.y,
              radius: 460.0,
              strength: 130.0,
            ));
          }
        }
      }

      // Asteroides massivos
      for (final asteroid in game.activeAsteroids) {
        if (asteroid.radius > 45.0) {
          final dx = (asteroid.position.x - camPos.x).abs();
          final dy = (asteroid.position.y - camPos.y).abs();
          if (dx < width * 0.75 && dy < height * 0.75) {
            gravityWells.add((
              x: asteroid.position.x,
              y: asteroid.position.y,
              radius: asteroid.radius * 3.5,
              strength: asteroid.radius * 0.85,
            ));
          }
        }
      }

      // Chefes de setor via registry O(1)
      for (final boss in game.activeBosses) {
        final dx = (boss.position.x - camPos.x).abs();
        final dy = (boss.position.y - camPos.y).abs();
        if (dx < width * 0.85 && dy < height * 0.85) {
          gravityWells.add((
            x: boss.position.x,
            y: boss.position.y,
            radius: 520.0,
            strength: 125.0,
          ));
        }
      }

      // Naves de elite / transportadores gravitacionais
      for (final enemy in game.activeEnemies) {
        final isHeavy =
            enemy.type == EnemyType.eliteCommander ||
            enemy.type == EnemyType.carrierHive ||
            enemy.type == EnemyType.gravityWeaver;
        if (isHeavy) {
          final dx = (enemy.position.x - camPos.x).abs();
          final dy = (enemy.position.y - camPos.y).abs();
          if (dx < width * 0.85 && dy < height * 0.85) {
            gravityWells.add((
              x: enemy.position.x,
              y: enemy.position.y,
              radius: 380.0,
              strength: 75.0,
            ));
          }
        }
      }
    } catch (_) {}

    // 2. Calcula posição distorcida de cada vértice da grade
    for (int r = 0; r < rows; r++) {
      final baseWorldY = startWorldY + r * gridCellSize;
      for (int c = 0; c < cols; c++) {
        final baseWorldX = startWorldX + c * gridCellSize;
        final node = _gridNodes[r][c];

        node.worldX = baseWorldX;
        node.worldY = baseWorldY;

        double warpX = 0.0;
        double warpY = 0.0;

        // Distorção gravitacional: atração dos nós em direção aos centros de massa
        for (int i = 0; i < gravityWells.length; i++) {
          final well = gravityWells[i];
          final diffX = well.x - baseWorldX;
          final diffY = well.y - baseWorldY;
          final distSq = diffX * diffX + diffY * diffY;
          final maxDist = well.radius;

          if (distSq < maxDist * maxDist && distSq > 4.0) {
            final dist = math.sqrt(distSq);
            final factor = (1.0 - dist / maxDist);
            final pull = (well.strength * factor * factor) / (dist + 30.0);
            warpX += diffX * pull;
            warpY += diffY * pull;
          }
        }

        node.warpedX = baseWorldX + warpX;
        node.warpedY = baseWorldY + warpY;
      }
    }

    // 3. Renderiza as linhas vetoriais interligadas em um único drawPath (Zero-GC + 1 draw call)
    final sectorColor = game.currentSector.primaryColor;
    _gridLinePaint.color = sectorColor.withValues(alpha: 0.065);
    _gridLinePaint.strokeWidth = 1.0;

    _gridPath.reset();
    // Polilinhas horizontais distorcidas
    for (int r = 0; r < rows; r++) {
      final first = _gridNodes[r][0];
      _gridPath.moveTo(first.warpedX, first.warpedY);
      for (int c = 1; c < cols; c++) {
        final p = _gridNodes[r][c];
        _gridPath.lineTo(p.warpedX, p.warpedY);
      }
    }

    // Polilinhas verticais distorcidas
    for (int c = 0; c < cols; c++) {
      final first = _gridNodes[0][c];
      _gridPath.moveTo(first.warpedX, first.warpedY);
      for (int r = 1; r < rows; r++) {
        final p = _gridNodes[r][c];
        _gridPath.lineTo(p.warpedX, p.warpedY);
      }
    }
    canvas.drawPath(_gridPath, _gridLinePaint);

    // Micro-nós luminosos nas interseções de nós sob deformação gravitacional ativa
    for (int i = 0; i < gravityWells.length; i++) {
      final well = gravityWells[i];
      _gravityNodePaint.color = sectorColor.withValues(alpha: 0.18);
      canvas.drawCircle(
        Offset(well.x, well.y),
        well.strength * 0.15,
        _gravityNodePaint,
      );
    }
  }
}
