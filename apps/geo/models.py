import uuid
from django.contrib.gis.db import models as gis_models
from django.db import models


class Country(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    code = models.CharField(max_length=3, unique=True)  # ISO 3166-1 alpha-3
    geometry = gis_models.MultiPolygonField(srid=4326, null=True, blank=True)

    class Meta:
        verbose_name_plural = 'countries'
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.code})"


class Region(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    country = models.ForeignKey(Country, on_delete=models.CASCADE, related_name='regions')
    map_source_id = models.PositiveIntegerField(null=True, blank=True, db_index=True)
    geometry = gis_models.MultiPolygonField(srid=4326)
    centroid = gis_models.PointField(srid=4326, null=True, blank=True)
    neighbors = models.ManyToManyField('self', symmetrical=True, blank=True)
    is_coastal = models.BooleanField(default=False)
    sea_distances = models.JSONField(default=list, blank=True)
    population_weight = models.FloatField(default=1.0, help_text='Weight for unit generation rate')

    class Meta:
        ordering = ['country__name', 'name']

    def __str__(self):
        return f"{self.name}, {self.country.name}"

    def save(self, *args, **kwargs):
        if self.geometry and not self.centroid:
            self.centroid = self.geometry.centroid
        super().save(*args, **kwargs)


class CustomMap(models.Model):
    """User-created map with custom-drawn provinces."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    author = models.ForeignKey('accounts.User', on_delete=models.CASCADE, related_name='custom_maps')
    is_published = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.name} by {self.author}"


class CustomProvince(models.Model):
    """A single province (polygon) within a custom map."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    custom_map = models.ForeignKey(CustomMap, on_delete=models.CASCADE, related_name='provinces')
    name = models.CharField(max_length=200)
    color = models.CharField(max_length=7, blank=True, default='')  # hex color for editor display
    geometry = gis_models.PolygonField(srid=4326)
    centroid = gis_models.PointField(srid=4326, null=True, blank=True)
    properties = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.custom_map.name})"

    def save(self, *args, **kwargs):
        if self.geometry and not self.centroid:
            self.centroid = self.geometry.centroid
        super().save(*args, **kwargs)
