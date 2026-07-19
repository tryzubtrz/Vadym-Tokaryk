package ua.tryzub.setup;

import org.bukkit.Bukkit;
import org.bukkit.GameRule;
import org.bukkit.Material;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.block.data.type.Bed;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.plugin.java.JavaPlugin;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Locale;

/** Автоналаштування режимів Тризуб: лобі та арена BedWars. */
public final class TryzubSetupPlugin extends JavaPlugin implements Listener {

    private String mode;

    @Override
    public void onEnable() {
        saveDefaultConfig();
        mode = getConfig().getString("mode", "generic").toLowerCase(Locale.ROOT);
        Bukkit.getPluginManager().registerEvents(this, this);
        Bukkit.getScheduler().runTaskLater(this, this::bootstrap, 40L);
        getLogger().info("TryzubSetup увімкнено (режим: " + mode + ")");
    }

    private void bootstrap() {
        File marker = new File(getDataFolder(), "bootstrapped.flag");
        if (marker.exists() && !getConfig().getBoolean("force-rebuild", false)) {
            getLogger().info("Bootstrap уже виконано.");
            return;
        }
        World world = Bukkit.getWorlds().get(0);
        switch (mode) {
            case "lobby" -> buildMainLobby(world);
            case "minigames" -> buildMinigames(world);
            case "skyblock" -> prepareSkyblockHub(world);
            case "prison" -> preparePrisonHub(world);
            case "factions" -> prepareFactionsHub(world);
            case "survival" -> getLogger().info("Survival: ванільний світ готовий.");
            default -> getLogger().info("Немає будівельних задач для mode=" + mode);
        }
        try {
            getDataFolder().mkdirs();
            Files.writeString(marker.toPath(), "ok", StandardCharsets.UTF_8);
        } catch (IOException e) {
            getLogger().warning("Не вдалося записати marker: " + e.getMessage());
        }
    }

    private void buildMainLobby(World world) {
        world.setSpawnLocation(0, 101, 0);
        world.setGameRule(GameRule.DO_DAYLIGHT_CYCLE, false);
        world.setGameRule(GameRule.DO_WEATHER_CYCLE, false);
        world.setGameRule(GameRule.DO_MOB_SPAWNING, false);
        world.setGameRule(GameRule.ANNOUNCE_ADVANCEMENTS, false);
        world.setTime(6000);

        fill(world, -20, 100, -20, 20, 100, 20, Material.LIGHT_BLUE_CONCRETE);
        fill(world, -4, 100, -4, 4, 100, 4, Material.YELLOW_CONCRETE);
        world.getBlockAt(0, 101, 0).setType(Material.BEACON, false);
        for (int x = -22; x <= 22; x++) {
            for (int z = -22; z <= 22; z++) {
                if (Math.abs(x) == 22 || Math.abs(z) == 22) {
                    world.getBlockAt(x, 101, z).setType(Material.GLASS_PANE, false);
                    world.getBlockAt(x, 102, z).setType(Material.GLASS_PANE, false);
                }
            }
        }
        fill(world, -20, 101, -20, 20, 110, 20, Material.AIR);
        world.getBlockAt(0, 101, 0).setType(Material.BEACON, false);
        getLogger().info("Головне лобі збудовано (0,101,0).");
    }

    private void buildMinigames(World world) {
        world.setSpawnLocation(0, 121, 0);
        world.setGameRule(GameRule.DO_MOB_SPAWNING, false);
        world.setGameRule(GameRule.DO_DAYLIGHT_CYCLE, false);
        fill(world, -16, 120, -16, 16, 120, 16, Material.GRAY_CONCRETE);
        fill(world, -3, 120, -3, 3, 120, 3, Material.RED_CONCRETE);
        fill(world, -16, 121, -16, 16, 130, 16, Material.AIR);
        world.getBlockAt(0, 121, 0).setType(Material.END_ROD, false);

        int ay = 70;
        int az = 500;
        buildIsland(world, -40, ay, az, Material.RED_WOOL, Material.RED_BED, BlockFace.EAST);
        buildIsland(world, 40, ay, az, Material.BLUE_WOOL, Material.BLUE_BED, BlockFace.WEST);
        fill(world, -3, ay, az - 3, 3, ay, az + 3, Material.STONE_BRICKS);
        // не чистимо величезний об'єм повітря — це ламає тік сервера
        writeBedWarsArena(world, ay, az);
        getLogger().info("Лобі міні-ігор + арена BedWars Duo готові.");
    }

    private void buildIsland(World world, int cx, int y, int cz, Material wool, Material bed, BlockFace facing) {
        fill(world, cx - 6, y, cz - 6, cx + 6, y, cz + 6, Material.SMOOTH_STONE);
        fill(world, cx - 5, y, cz - 5, cx + 5, y, cz + 5, wool);
        for (int x = cx - 6; x <= cx + 6; x++) {
            world.getBlockAt(x, y + 1, cz - 6).setType(Material.OAK_FENCE, false);
            world.getBlockAt(x, y + 1, cz + 6).setType(Material.OAK_FENCE, false);
        }
        placeBed(world, cx, y + 1, cz - 3, bed, facing);
        world.getBlockAt(cx, y + 1, cz + 3).setType(Material.CRAFTING_TABLE, false);
        world.getBlockAt(cx + 1, y + 1, cz + 3).setType(Material.CHEST, false);
    }

    private void placeBed(World world, int x, int y, int z, Material bedMaterial, BlockFace facing) {
        Block foot = world.getBlockAt(x, y, z);
        Block head = foot.getRelative(facing);
        foot.setType(bedMaterial, false);
        head.setType(bedMaterial, false);
        Bed footData = (Bed) foot.getBlockData();
        footData.setPart(Bed.Part.FOOT);
        footData.setFacing(facing);
        foot.setBlockData(footData, false);
        Bed headData = (Bed) head.getBlockData();
        headData.setPart(Bed.Part.HEAD);
        headData.setFacing(facing);
        head.setBlockData(headData, false);
    }

    private void writeBedWarsArena(World world, int ay, int az) {
        File arenas = new File("plugins/BedWars/arenas");
        arenas.mkdirs();
        File file = new File(arenas, "tryzub-duo.yml");
        String w = world.getName();
        int bedY = ay + 1;
        int spawnY = ay + 1;
        String yaml = ""
            + "name: TryzubDuo\n"
            + "pauseCountdown: 10\n"
            + "gameTime: 3600\n"
            + "world: " + w + "\n"
            + "pos1: -70.0;" + (ay + 40) + ".0;460.0;0.0;0.0\n"
            + "pos2: 70.0;" + (ay - 5) + ".0;540.0;0.0;0.0\n"
            + "specSpawn: 0.5;" + (ay + 10) + ".0;" + az + ".5;0.0;30.0\n"
            + "lobbySpawn: 0.5;121.0;0.5;0.0;0.0\n"
            + "lobbySpawnWorld: " + w + "\n"
            + "minPlayers: 2\n"
            + "postGameWaiting: 10\n"
            + "customPrefix: '&9Тризуб&7'\n"
            + "teams:\n"
            + "  Red:\n"
            + "    isNewColor: true\n"
            + "    color: RED\n"
            + "    maxPlayers: 4\n"
            + "    bed: -40.0;" + bedY + ".0;" + (az - 3) + ".0;0.0;0.0\n"
            + "    spawn: -40.5;" + spawnY + ".0;" + az + ".5;90.0;0.0\n"
            + "    actualName: Червоні\n"
            + "  Blue:\n"
            + "    isNewColor: true\n"
            + "    color: BLUE\n"
            + "    maxPlayers: 4\n"
            + "    bed: 40.0;" + bedY + ".0;" + (az - 3) + ".0;0.0;0.0\n"
            + "    spawn: 40.5;" + spawnY + ".0;" + az + ".5;-90.0;0.0\n"
            + "    actualName: Сині\n"
            + "spawners:\n"
            + "- location: 0.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: bronze\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: null\n"
            + "  maxSpawnedResources: -1\n"
            + "- location: -40.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: iron\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: Red\n"
            + "  maxSpawnedResources: -1\n"
            + "- location: 40.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: iron\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: Blue\n"
            + "  maxSpawnedResources: -1\n"
            + "- location: 0.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  type: gold\n"
            + "  customName: null\n"
            + "  startLevel: 1.0\n"
            + "  hologramEnabled: true\n"
            + "  team: null\n"
            + "  maxSpawnedResources: -1\n"
            + "stores:\n"
            + "- loc: -38.5;" + (ay + 1) + ".0;" + az + ".5;0.0;0.0\n"
            + "  shop: shop.yml\n"
            + "  parent: 'true'\n"
            + "  type: VILLAGER\n"
            + "  name: '&aКрамниця'\n"
            + "  isBaby: 'false'\n"
            + "  skin: null\n"
            + "  team: Red\n"
            + "- loc: 38.5;" + (ay + 1) + ".0;" + az + ".5;180.0;0.0\n"
            + "  shop: shop.yml\n"
            + "  parent: 'true'\n"
            + "  type: VILLAGER\n"
            + "  name: '&aКрамниця'\n"
            + "  isBaby: 'false'\n"
            + "  skin: null\n"
            + "  team: Blue\n";
        try {
            Files.writeString(file.toPath(), yaml, StandardCharsets.UTF_8);
            getLogger().info("Записано арену BedWars: " + file.getName());
        } catch (IOException e) {
            getLogger().severe("Не вдалося записати арену: " + e.getMessage());
        }
    }

    private void prepareSkyblockHub(World world) {
        world.setSpawnLocation(0, 101, 0);
        fill(world, -12, 100, -12, 12, 100, 12, Material.GRASS_BLOCK);
        fill(world, -12, 101, -12, 12, 110, 12, Material.AIR);
        getLogger().info("Хаб Skyblock готовий. Команда: /is create");
    }

    private void preparePrisonHub(World world) {
        world.setSpawnLocation(0, 101, 0);
        fill(world, -16, 100, -16, 16, 100, 16, Material.STONE_BRICKS);
        fill(world, 30, 60, -10, 50, 80, 10, Material.STONE);
        fill(world, 32, 62, -8, 48, 78, 8, Material.AIR);
        for (int i = 0; i < 80; i++) {
            int x = 32 + (i * 7) % 16;
            int y = 62 + (i * 3) % 16;
            int z = -8 + (i * 5) % 16;
            world.getBlockAt(x, y, z).setType(Material.COAL_ORE, false);
        }
        getLogger().info("Хаб Prison + тестова шахта готові.");
    }

    private void prepareFactionsHub(World world) {
        world.setSpawnLocation(0, 80, 0);
        fill(world, -10, 79, -10, 10, 79, 10, Material.GRASS_BLOCK);
        getLogger().info("Хаб Factions готовий. Команда: /f create <назва>");
    }

    private void fill(World world, int x1, int y1, int z1, int x2, int y2, int z2, Material mat) {
        int minX = Math.min(x1, x2), maxX = Math.max(x1, x2);
        int minY = Math.min(y1, y2), maxY = Math.max(y1, y2);
        int minZ = Math.min(z1, z2), maxZ = Math.max(z1, z2);
        for (int x = minX; x <= maxX; x++) {
            for (int y = minY; y <= maxY; y++) {
                for (int z = minZ; z <= maxZ; z++) {
                    world.getBlockAt(x, y, z).setType(mat, false);
                }
            }
        }
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent event) {
        Player p = event.getPlayer();
        String msg = switch (mode) {
            case "lobby" -> "§9§lТризуб §7| §fГоловне лобі. Відкрий §eВибір сервера §fабо §a/server";
            case "minigames" -> "§c§lМіні-ігри §7| §fBedWars: §a/bw join TryzubDuo §7| Назад: §a/server lobby";
            case "skyblock" -> "§b§lSkyblock §7| §fСтвори острів: §a/is create";
            case "prison" -> "§6§lPrison §7| §fКоманди: §a/ranks §7| §a/mines";
            case "factions" -> "§5§lFactions §7| §fСтвори фракцію: §a/f create <назва>";
            case "survival" -> "§2§lSurvival §7| §fВиживання. §a/sethome §7| §a/claim";
            default -> "§9Тризуб §7| Ласкаво просимо!";
        };
        event.setJoinMessage("§a+ §f" + p.getName());
        Bukkit.getScheduler().runTaskLater(this, () -> p.sendMessage(msg), 20L);
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!sender.hasPermission("tryzub.setup")) {
            sender.sendMessage("§cНемає прав.");
            return true;
        }
        if (args.length > 0 && args[0].equalsIgnoreCase("rebuild")) {
            getConfig().set("force-rebuild", true);
            saveConfig();
            //noinspection ResultOfMethodCallIgnored
            new File(getDataFolder(), "bootstrapped.flag").delete();
            bootstrap();
            getConfig().set("force-rebuild", false);
            saveConfig();
            sender.sendMessage("§aПеребудовано.");
            return true;
        }
        sender.sendMessage("§e/tryzubsetup rebuild");
        return true;
    }
}
