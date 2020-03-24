class SensorEvent<E> {
  final DateTime time;
  final E event;
  SensorEvent(this.time, this.event);

  @override
  String toString() => '<$time, $event>';
}