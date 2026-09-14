import 'package:flutter/material.dart';

/// Listado de tarjetas que se reparte en varias columnas cuando hay ancho.
///
/// En un teléfono se comporta exactamente como un `ListView.builder`. A partir
/// de [minColumnWidth] de ancho disponible empieza a repartir las tarjetas en
/// columnas, hasta [maxColumns]: es la diferencia entre una tarjeta estirada a
/// lo ancho de un monitor y una rejilla que se lee de un vistazo.
///
/// El número de columnas se calcula sobre el ancho **disponible**, no sobre el
/// de la pantalla, para que funcione igual dentro de un panel lateral o de un
/// fold a medio abrir.
class AdaptiveCardList extends StatelessWidget {
  const AdaptiveCardList({
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.minColumnWidth = 400,
    this.maxColumns = 3,
    this.columnSpacing = 12,
    this.shrinkWrap = false,
    this.physics,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  /// Ancho mínimo que se le concede a una tarjeta antes de abrir otra columna.
  final double minColumnWidth;

  /// Tope de columnas: más de tres obliga a barrer la pantalla con la vista.
  final int maxColumns;

  final double columnSpacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Columnas que caben en [width].
  int columnsFor(double width) =>
      (width / minColumnWidth).floor().clamp(1, maxColumns);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);

        if (columns == 1) {
          return ListView.builder(
            controller: controller,
            padding: padding,
            itemCount: itemCount,
            shrinkWrap: shrinkWrap,
            physics: physics,
            itemBuilder: itemBuilder,
          );
        }

        final rows = (itemCount / columns).ceil();

        return ListView.builder(
          controller: controller,
          padding: padding,
          itemCount: rows,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemBuilder: (context, row) {
            final children = <Widget>[];
            for (var col = 0; col < columns; col++) {
              if (col > 0) children.add(SizedBox(width: columnSpacing));
              final index = row * columns + col;
              children.add(
                Expanded(
                  // El hueco de la última fila incompleta se rellena para que
                  // las tarjetas no se ensanchen al quedarse solas.
                  child: index < itemCount
                      ? (itemBuilder(context, index) ?? const SizedBox.shrink())
                      : const SizedBox.shrink(),
                ),
              );
            }

            // Iguala la altura de las tarjetas de la fila; si no, los bordes
            // inferiores quedan desalineados y la rejilla se ve descuidada.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            );
          },
        );
      },
    );
  }
}

/// Reparte [items] en filas de [columns] columnas.
///
/// Es la versión para listas ya construidas (por ejemplo un listado agrupado
/// por secciones, donde las tarjetas van intercaladas con cabeceras y no se
/// pueden indexar de corrido). Con `columns == 1` devuelve la lista tal cual.
///
/// Una sola tarjeta tambien se reparte: si se devolvia tal cual, un grupo con
/// un unico elemento se estiraba de lado a lado de la pantalla y rompia la
/// rejilla de los grupos vecinos.
List<Widget> adaptiveRows(
  List<Widget> items, {
  required int columns,
  double spacing = 12,
}) {
  if (columns <= 1 || items.isEmpty) return items;

  final rows = <Widget>[];
  for (var i = 0; i < items.length; i += columns) {
    final children = <Widget>[];
    for (var col = 0; col < columns; col++) {
      if (col > 0) children.add(SizedBox(width: spacing));
      final index = i + col;
      children.add(
        Expanded(
          child: index < items.length ? items[index] : const SizedBox.shrink(),
        ),
      );
    }
    rows.add(
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
  return rows;
}

/// Columnas que caben en [width] para tarjetas de al menos [minColumnWidth].
int adaptiveColumnsFor(
  double width, {
  double minColumnWidth = 400,
  int maxColumns = 3,
}) => (width / minColumnWidth).floor().clamp(1, maxColumns);
