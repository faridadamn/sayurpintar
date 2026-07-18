import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';

class StatusStep {
  final String label;
  final String? description;
  final IconData icon;
  final DateTime? timestamp;

  const StatusStep({
    required this.label,
    this.description,
    required this.icon,
    this.timestamp,
  });
}

class StatusTimeline extends StatelessWidget {
  final List<StatusStep> steps;
  final int currentStep;
  final Axis direction;
  final double iconSize;
  final double lineWidth;

  const StatusTimeline({
    super.key,
    required this.steps,
    required this.currentStep,
    this.direction = Axis.horizontal,
    this.iconSize = 28,
    this.lineWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.horizontal) {
      return _buildHorizontal();
    }
    return _buildVertical();
  }

  Widget _buildHorizontal() {
    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;
        final state = _getStepState(index);

        return Expanded(
          child: Row(
            children: [
              _StepNode(
                step: step,
                state: state,
                iconSize: iconSize,
              ),
              if (!isLast)
                Expanded(
                  child: _ConnectingLine(
                    isCompleted: state == _StepState.completed,
                    lineWidth: lineWidth,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVertical() {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;
        final state = _getStepState(index);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _StepNode(
                    step: step,
                    state: state,
                    iconSize: iconSize,
                  ),
                  if (!isLast)
                    Expanded(
                      child: _VerticalLine(
                        isCompleted: state == _StepState.completed,
                        lineWidth: lineWidth,
                      ),
                    ),
                ],
              ),
              if (!isLast || step.description != null || step.timestamp != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppTheme.space12,
                      top: AppTheme.space4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: state == _StepState.pending
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: state == _StepState.pending
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        if (step.description != null) ...[
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            step.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        if (step.timestamp != null) ...[
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            _formatTimestamp(step.timestamp!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTheme.space12),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  _StepState _getStepState(int index) {
    if (index < currentStep) return _StepState.completed;
    if (index == currentStep) return _StepState.active;
    return _StepState.pending;
  }

  String _formatTimestamp(DateTime dt) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

enum _StepState { completed, active, pending }

class _StepNode extends StatelessWidget {
  final StatusStep step;
  final _StepState state;
  final double iconSize;

  const _StepNode({
    required this.step,
    required this.state,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = state == _StepState.completed
        ? AppTheme.primaryGreen
        : state == _StepState.active
            ? AppTheme.primaryLight
            : AppTheme.divider.withOpacity(0.4);

    final iconColor =
        state == _StepState.pending ? AppTheme.textSecondary : Colors.white;

    final icon = state == _StepState.completed ? Icons.check : step.icon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: state == _StepState.active
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: iconSize * 0.5,
            color: iconColor,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                state == _StepState.pending ? FontWeight.w400 : FontWeight.w600,
            color: state == _StepState.pending
                ? AppTheme.textSecondary
                : AppTheme.primaryDark,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ConnectingLine extends StatelessWidget {
  final bool isCompleted;
  final double lineWidth;

  const _ConnectingLine({
    required this.isCompleted,
    required this.lineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: lineWidth,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.primaryGreen
            : AppTheme.divider.withOpacity(0.4),
        borderRadius: BorderRadius.circular(lineWidth / 2),
      ),
    );
  }
}

class _VerticalLine extends StatelessWidget {
  final bool isCompleted;
  final double lineWidth;

  const _VerticalLine({
    required this.isCompleted,
    required this.lineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: lineWidth,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppTheme.primaryGreen
              : AppTheme.divider.withOpacity(0.4),
          borderRadius: BorderRadius.circular(lineWidth / 2),
        ),
      ),
    );
  }
}
