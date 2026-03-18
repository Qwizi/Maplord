"""Dynamic admin forms for system module configuration."""
import json

from django import forms


class SystemModuleForm(forms.ModelForm):
    """
    Custom form that generates typed fields from config_schema.

    Instead of editing raw JSON, admins see proper form fields:
    - int → NumberInput with min/max
    - float → NumberInput with step=0.01
    - bool → CheckboxInput
    - str → TextInput (or Select if 'options' defined)
    - list → Textarea (JSON array)
    """

    class Meta:
        from apps.game_config.models import SystemModule
        model = SystemModule
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance and self.instance.pk:
            self._generate_config_fields()

    def _generate_config_fields(self):
        """Generate form fields from config_schema."""
        schema = self.instance.config_schema or []
        config = self.instance.config or {}

        for field_def in schema:
            key = field_def.get('key', '')
            if not key:
                continue

            field_name = f'cfg__{key}'
            label = field_def.get('label', key)
            field_type = field_def.get('type', 'str')
            default = field_def.get('default')
            value = config.get(key, default)

            if field_type == 'int':
                field = forms.IntegerField(
                    label=label,
                    required=False,
                    initial=value,
                    min_value=field_def.get('min'),
                    max_value=field_def.get('max'),
                    widget=forms.NumberInput(attrs={
                        'class': 'border-border bg-background text-foreground',
                        'style': 'max-width: 200px;',
                    }),
                )
            elif field_type == 'float':
                field = forms.FloatField(
                    label=label,
                    required=False,
                    initial=value,
                    min_value=field_def.get('min'),
                    max_value=field_def.get('max'),
                    widget=forms.NumberInput(attrs={
                        'step': '0.01',
                        'class': 'border-border bg-background text-foreground',
                        'style': 'max-width: 200px;',
                    }),
                )
            elif field_type == 'bool':
                field = forms.BooleanField(
                    label=label,
                    required=False,
                    initial=value,
                )
            elif field_type == 'str' and 'options' in field_def:
                choices = [(o, o) for o in field_def['options']]
                field = forms.ChoiceField(
                    label=label,
                    required=False,
                    initial=value,
                    choices=choices,
                )
            elif field_type == 'list':
                field = forms.CharField(
                    label=label,
                    required=False,
                    initial=json.dumps(value) if isinstance(value, list) else str(value),
                    widget=forms.Textarea(attrs={
                        'rows': 3,
                        'class': 'border-border bg-background text-foreground font-mono text-sm',
                        'placeholder': '["item1", "item2"]',
                    }),
                    help_text='JSON array',
                )
            else:
                field = forms.CharField(
                    label=label,
                    required=False,
                    initial=value or '',
                )

            self.fields[field_name] = field

    def clean(self):
        cleaned = super().clean()

        # Collect cfg__ fields back into the config dict
        schema = self.instance.config_schema if self.instance else []
        if not schema:
            return cleaned

        config = dict(self.instance.config or {}) if self.instance else {}
        for field_def in schema:
            key = field_def.get('key', '')
            field_name = f'cfg__{key}'
            if field_name not in cleaned:
                continue

            value = cleaned[field_name]
            field_type = field_def.get('type', 'str')

            if field_type == 'list' and isinstance(value, str):
                try:
                    value = json.loads(value)
                except (json.JSONDecodeError, TypeError):
                    value = field_def.get('default', [])

            if value is not None:
                config[key] = value

        cleaned['config'] = config
        return cleaned

    def get_config_fieldnames(self):
        """Return list of dynamic config field names for fieldset building."""
        return [name for name in self.fields if name.startswith('cfg__')]
