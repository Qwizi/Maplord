import uuid

from django.core.management.base import BaseCommand

from apps.accounts.models import User

BOT_NAMES = [
    "Bot Alpha",
    "Bot Bravo",
    "Bot Charlie",
    "Bot Delta",
    "Bot Echo",
    "Bot Foxtrot",
    "Bot Golf",
    "Bot Hotel",
]


class Command(BaseCommand):
    help = "Create bot users for AI opponents (idempotent)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--count",
            type=int,
            default=8,
            help="Number of bot users to create (max 8)",
        )

    def handle(self, *args, **options):
        count = min(options["count"], len(BOT_NAMES))
        created = 0

        for i in range(count):
            name = BOT_NAMES[i]
            email = f"bot-{name.split()[1].lower()}@maplord.local"
            bot_uuid = uuid.UUID(f"00000000-0000-4000-b000-00000000000{i + 1}")

            _, was_created = User.objects.update_or_create(
                id=bot_uuid,
                defaults={
                    "username": name,
                    "email": email,
                    "is_active": False,
                    "is_bot": True,
                    "elo_rating": 1000,
                    "password": "!",
                },
            )
            if was_created:
                created += 1

        self.stdout.write(
            self.style.SUCCESS(f"Done: {created} created, {count - created} already existed")
        )
