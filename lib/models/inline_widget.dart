/// Inline Widget Data Model
/// 
/// Supports generative UI widgets that appear inline in chat messages,
/// similar to ChatGPT's inline widgets for weather, charts, etc.

/// Widget types that can appear inline in chat
enum InlineWidgetType {
  weather,
  chart,
  card,
  code,
  data,
  link,
  image,
  map,
  forecast,
  status,
  action,
}

/// Base inline widget data
class InlineWidgetData {
  final InlineWidgetType type;
  final Map<String, dynamic> data;
  final String? title;
  final String? subtitle;
  final bool animated;
  
  const InlineWidgetData({
    required this.type,
    required this.data,
    this.title,
    this.subtitle,
    this.animated = true,
  });
  
  factory InlineWidgetData.fromJson(Map<String, dynamic> json) {
    return InlineWidgetData(
      type: InlineWidgetType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => InlineWidgetType.card,
      ),
      data: json['data'] ?? {},
      title: json['title'],
      subtitle: json['subtitle'],
      animated: json['animated'] ?? true,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
    'title': title,
    'subtitle': subtitle,
    'animated': animated,
  };
}

/// Weather widget data - for inline weather display
class WeatherWidgetData extends InlineWidgetData {
  WeatherWidgetData({
    required String location,
    required double temperature,
    required String condition,
    String? description,
    int? humidity,
    double? windSpeed,
    int? pressure,
    String? iconCode,
    String? country,
    double? feelsLike,
    bool? isNight,
    List<ForecastDayWidgetData>? forecast,
  }) : super(
    type: InlineWidgetType.weather,
    data: {
      'location': location,
      'temperature': temperature,
      'condition': condition,
      'description': description,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'pressure': pressure,
      'iconCode': iconCode,
      'country': country,
      'feelsLike': feelsLike,
      'isNight': isNight,
      'forecast': forecast?.map((f) => f.toJson()).toList(),
    },
  );
  
  factory WeatherWidgetData.fromMap(Map<String, dynamic> map) {
    final forecastData = map['forecast'] as List? ?? [];
    final forecast = forecastData
        .map((f) => ForecastDayWidgetData.fromJson(f as Map<String, dynamic>))
        .toList();
    
    return WeatherWidgetData(
      location: map['location'] ?? 'Unknown',
      temperature: (map['temperature'] ?? 0).toDouble(),
      condition: map['condition'] ?? 'Unknown',
      description: map['description'],
      humidity: map['humidity'],
      windSpeed: map['windSpeed'] != null 
          ? (map['windSpeed'] as num).toDouble() 
          : null,
      pressure: map['pressure'],
      iconCode: map['iconCode'],
      country: map['country'],
      feelsLike: map['feelsLike'] != null 
          ? (map['feelsLike'] as num).toDouble() 
          : null,
      isNight: map['isNight'],
      forecast: forecast.isNotEmpty ? forecast : null,
    );
  }
  
  String get location => data['location'] ?? 'Unknown';
  double get temperature => (data['temperature'] ?? 0).toDouble();
  String get condition => data['condition'] ?? 'Unknown';
  String? get description => data['description'];
  int? get humidity => data['humidity'];
  double? get windSpeed => data['windSpeed']?.toDouble();
  int? get pressure => data['pressure'];
  String? get iconCode => data['iconCode'];
  String? get country => data['country'];
  double? get feelsLike => data['feelsLike']?.toDouble();
  bool get isNight => data['isNight'] ?? false;
  List<ForecastDayWidgetData> get forecast {
    final forecastData = data['forecast'] as List? ?? [];
    return forecastData
        .map((f) => ForecastDayWidgetData.fromJson(f as Map<String, dynamic>))
        .toList();
  }
}

/// Forecast widget data for daily forecasts
class ForecastDayWidgetData {
  final DateTime date;
  final double high;
  final double low;
  final String condition;
  final String? iconCode;
  final int? precipitationChance;
  
  const ForecastDayWidgetData({
    required this.date,
    required this.high,
    required this.low,
    required this.condition,
    this.iconCode,
    this.precipitationChance,
  });
  
  factory ForecastDayWidgetData.fromJson(Map<String, dynamic> json) {
    return ForecastDayWidgetData(
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      high: (json['high'] ?? json['tempMax'] ?? 0).toDouble(),
      low: (json['low'] ?? json['tempMin'] ?? 0).toDouble(),
      condition: json['condition'] ?? 'Unknown',
      iconCode: json['iconCode'],
      precipitationChance: json['precipitationChance'] ?? json['pop'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'high': high,
    'low': low,
    'condition': condition,
    'iconCode': iconCode,
    'precipitationChance': precipitationChance,
  };
}

/// Chart widget data - for inline charts
class ChartWidgetData extends InlineWidgetData {
  ChartWidgetData({
    required List<ChartDataPoint> points,
    ChartType chartType = ChartType.line,
    String? xAxisLabel,
    String? yAxisLabel,
    List<String>? labels,
  }) : super(
    type: InlineWidgetType.chart,
    data: {
      'points': points.map((p) => p.toJson()).toList(),
      'chartType': chartType.name,
      'xAxisLabel': xAxisLabel,
      'yAxisLabel': yAxisLabel,
      'labels': labels,
    },
  );
  
  factory ChartWidgetData.fromMap(Map<String, dynamic> map) {
    final pointsData = map['points'] as List? ?? [];
    final points = pointsData
        .map((p) => ChartDataPoint.fromJson(p as Map<String, dynamic>))
        .toList();
    
    return ChartWidgetData(
      points: points,
      chartType: ChartType.values.firstWhere(
        (t) => t.name == map['chartType'],
        orElse: () => ChartType.line,
      ),
      xAxisLabel: map['xAxisLabel'],
      yAxisLabel: map['yAxisLabel'],
      labels: (map['labels'] as List?)?.cast<String>(),
    );
  }
  
  List<ChartDataPoint> get points {
    final pointsData = data['points'] as List? ?? [];
    return pointsData
        .map((p) => ChartDataPoint.fromJson(p as Map<String, dynamic>))
        .toList();
  }
  
  ChartType get chartType => ChartType.values.firstWhere(
    (t) => t.name == data['chartType'],
    orElse: () => ChartType.line,
  );
  
  String? get xAxisLabel => data['xAxisLabel'];
  String? get yAxisLabel => data['yAxisLabel'];
  List<String>? get labels => (data['labels'] as List?)?.cast<String>();
}

/// Forecast widget data for inline forecast display
class ForecastWidgetData extends InlineWidgetData {
  ForecastWidgetData({
    required String location,
    required List<ForecastDayWidgetData> days,
    String? country,
  }) : super(
    type: InlineWidgetType.forecast,
    data: {
      'location': location,
      'country': country,
      'days': days.map((d) => d.toJson()).toList(),
    },
  );
  
  factory ForecastWidgetData.fromMap(Map<String, dynamic> map) {
    final daysData = map['days'] as List? ?? [];
    final days = daysData
        .map((d) => ForecastDayWidgetData.fromJson(d as Map<String, dynamic>))
        .toList();
    
    return ForecastWidgetData(
      location: map['location'] ?? 'Unknown',
      days: days,
      country: map['country'],
    );
  }
  
  String get location => data['location'] ?? 'Unknown';
  String? get country => data['country'];
  List<ForecastDayWidgetData> get days {
    final daysData = data['days'] as List? ?? [];
    return daysData
        .map((d) => ForecastDayWidgetData.fromJson(d as Map<String, dynamic>))
        .toList();
  }
}

/// Chart types
enum ChartType {
  line,
  bar,
  pie,
  area,
  scatter,
}

/// Chart data point
class ChartDataPoint {
  final double x;
  final double y;
  final String? label;
  final String? color;
  
  const ChartDataPoint({
    required this.x,
    required this.y,
    this.label,
    this.color,
  });
  
  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      x: (json['x'] ?? json['value'] ?? 0).toDouble(),
      y: (json['y'] ?? json['value'] ?? 0).toDouble(),
      label: json['label'],
      color: json['color'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'label': label,
    'color': color,
  };
}

/// Info card widget data - for inline info cards
class InfoCardWidgetData extends InlineWidgetData {
  InfoCardWidgetData({
    required String title,
    String? description,
    String? icon,
    String? color,
    List<InfoCardAction>? actions,
    Map<String, dynamic>? metadata,
  }) : super(
    type: InlineWidgetType.card,
    title: title,
    data: {
      'description': description,
      'icon': icon,
      'color': color,
      'actions': actions?.map((a) => a.toJson()).toList(),
      'metadata': metadata,
    },
  );
  
  factory InfoCardWidgetData.fromMap(Map<String, dynamic> map) {
    final actionsData = map['actions'] as List? ?? [];
    final actions = actionsData
        .map((a) => InfoCardAction.fromJson(a as Map<String, dynamic>))
        .toList();
    
    return InfoCardWidgetData(
      title: map['title'] ?? '',
      description: map['description'],
      icon: map['icon'],
      color: map['color'],
      actions: actions.isNotEmpty ? actions : null,
      metadata: map['metadata'],
    );
  }
  
  String get description => data['description'] ?? '';
  String? get icon => data['icon'];
  String? get color => data['color'];
  List<InfoCardAction>? get actions {
    final actionsData = data['actions'] as List? ?? [];
    if (actionsData.isEmpty) return null;
    return actionsData
        .map((a) => InfoCardAction.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}

/// Info card action
class InfoCardAction {
  final String label;
  final String? icon;
  final String? action;
  final Map<String, dynamic>? params;
  
  const InfoCardAction({
    required this.label,
    this.icon,
    this.action,
    this.params,
  });
  
  factory InfoCardAction.fromJson(Map<String, dynamic> json) {
    return InfoCardAction(
      label: json['label'] ?? '',
      icon: json['icon'],
      action: json['action'],
      params: json['params'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'label': label,
    'icon': icon,
    'action': action,
    'params': params,
  };
}

/// Status widget data - for inline status indicators
class StatusWidgetData extends InlineWidgetData {
  StatusWidgetData({
    required String status,
    String? message,
    String? color,
    List<StatusItem>? items,
  }) : super(
    type: InlineWidgetType.status,
    data: {
      'status': status,
      'message': message,
      'color': color,
      'items': items?.map((i) => i.toJson()).toList(),
    },
  );
  
  factory StatusWidgetData.fromMap(Map<String, dynamic> map) {
    final itemsData = map['items'] as List? ?? [];
    final items = itemsData
        .map((i) => StatusItem.fromJson(i as Map<String, dynamic>))
        .toList();
    
    return StatusWidgetData(
      status: map['status'] ?? 'unknown',
      message: map['message'],
      color: map['color'],
      items: items.isNotEmpty ? items : null,
    );
  }
  
  String get status => data['status'] ?? 'unknown';
  String? get message => data['message'];
  String? get color => data['color'];
  List<StatusItem>? get items {
    final itemsData = data['items'] as List? ?? [];
    if (itemsData.isEmpty) return null;
    return itemsData
        .map((i) => StatusItem.fromJson(i as Map<String, dynamic>))
        .toList();
  }
}

/// Status item
class StatusItem {
  final String label;
  final String value;
  final String? color;
  final String? icon;
  
  const StatusItem({
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });
  
  factory StatusItem.fromJson(Map<String, dynamic> json) {
    return StatusItem(
      label: json['label'] ?? '',
      value: json['value'] ?? '',
      color: json['color'],
      icon: json['icon'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'color': color,
    'icon': icon,
  };
}

/// Helper to parse widget data from agent response
InlineWidgetData? parseInlineWidget(Map<String, dynamic> json) {
  final typeStr = json['type'] as String?;
  if (typeStr == null) return null;
  
  final type = InlineWidgetType.values.firstWhere(
    (t) => t.name == typeStr,
    orElse: () => InlineWidgetType.card,
  );
  
  switch (type) {
    case InlineWidgetType.weather:
      return WeatherWidgetData.fromMap(json['data'] ?? json);
    case InlineWidgetType.chart:
      return ChartWidgetData.fromMap(json['data'] ?? json);
    case InlineWidgetType.card:
      return InfoCardWidgetData.fromMap(json['data'] ?? json);
    case InlineWidgetType.status:
      return StatusWidgetData.fromMap(json['data'] ?? json);
    default:
      return InlineWidgetData.fromJson(json);
  }
}