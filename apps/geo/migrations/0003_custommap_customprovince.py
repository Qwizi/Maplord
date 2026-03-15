import django.contrib.gis.db.models.fields
import django.db.models.deletion
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("geo", "0002_region_map_source_id_region_sea_distances"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="CustomMap",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("name", models.CharField(max_length=200)),
                ("description", models.TextField(blank=True)),
                ("is_published", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("author", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="custom_maps", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-updated_at"],
            },
        ),
        migrations.CreateModel(
            name="CustomProvince",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("name", models.CharField(max_length=200)),
                ("color", models.CharField(blank=True, default="", max_length=7)),
                ("geometry", django.contrib.gis.db.models.fields.PolygonField(srid=4326)),
                ("centroid", django.contrib.gis.db.models.fields.PointField(blank=True, null=True, srid=4326)),
                ("properties", models.JSONField(blank=True, default=dict)),
                ("custom_map", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="provinces", to="geo.custommap")),
            ],
            options={
                "ordering": ["name"],
            },
        ),
    ]
