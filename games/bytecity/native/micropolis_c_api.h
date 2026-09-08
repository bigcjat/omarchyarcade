#ifndef MICROPOLIS_C_API_H
#define MICROPOLIS_C_API_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// World dimensions in tiles
#define BYTECITY_WORLD_W 120
#define BYTECITY_WORLD_H 100

// Tools mapping to Micropolis EditingTool
typedef enum {
    BC_TOOL_RESIDENTIAL = 0,
    BC_TOOL_COMMERCIAL = 1,
    BC_TOOL_INDUSTRIAL = 2,
    BC_TOOL_FIRESTATION = 3,
    BC_TOOL_POLICESTATION = 4,
    BC_TOOL_QUERY = 5,
    BC_TOOL_WIRE = 6,
    BC_TOOL_BULLDOZER = 7,
    BC_TOOL_RAILROAD = 8,
    BC_TOOL_ROAD = 9,
    BC_TOOL_STADIUM = 10,
    BC_TOOL_PARK = 11,
    BC_TOOL_SEAPORT = 12,
    BC_TOOL_COALPOWER = 13,
    BC_TOOL_NUCLEARPOWER = 14,
    BC_TOOL_AIRPORT = 15,
    BC_TOOL_NETWORK = 16,
    BC_TOOL_WATER = 17,
    BC_TOOL_LAND = 18,
    BC_TOOL_FOREST = 19
} ByteCityTool;

// Tool results
typedef enum {
    BYTECITY_TOOL_NO_MONEY = -2,
    BYTECITY_TOOL_NEED_BULLDOZE = -1,
    BYTECITY_TOOL_FAILED = 0,
    BYTECITY_TOOL_OK = 1
} ByteCityToolResult;

// Disasters
typedef enum {
    DISASTER_FIRE = 0,
    DISASTER_FLOOD = 1,
    DISASTER_MONSTER = 2,
    DISASTER_TORNADO = 3,
    DISASTER_EARTHQUAKE = 4,
    DISASTER_MELTDOWN = 5
} ByteCityDisaster;

// Opaque engine pointer
typedef void* ByteCityHandle;

// Lifecycle
ByteCityHandle bytecity_create(void);
void bytecity_destroy(ByteCityHandle handle);

// Map generation & simulation
void bytecity_generate_map(ByteCityHandle handle, int seed);
void bytecity_tick(ByteCityHandle handle);
void bytecity_set_speed(ByteCityHandle handle, int speed); // 0=pause, 1=slow, 2=med, 3=fast

// Tile map buffer access (120 * 100 uint16 array, column-major: x * 100 + y)
uint16_t bytecity_get_tile(ByteCityHandle handle, int x, int y);
void bytecity_copy_map(ByteCityHandle handle, uint16_t* dest_buffer);
const uint16_t* bytecity_get_map_ptr(ByteCityHandle handle);
const uint8_t* bytecity_get_power_map_ptr(ByteCityHandle handle);

// Tools & Building
int bytecity_do_tool(ByteCityHandle handle, int tool_id, int x, int y);
bool bytecity_has_power(ByteCityHandle handle, int x, int y);
void bytecity_refresh_power(ByteCityHandle handle);

// Economy & City State
int64_t bytecity_get_funds(ByteCityHandle handle);
void bytecity_set_funds(ByteCityHandle handle, int64_t funds);

int bytecity_get_tax_rate(ByteCityHandle handle);
void bytecity_set_tax_rate(ByteCityHandle handle, int rate);

int bytecity_get_population(ByteCityHandle handle);
int bytecity_get_year(ByteCityHandle handle);
int bytecity_get_month(ByteCityHandle handle);

// RCI Demand: valves range from approx -2000 to +2000
void bytecity_get_demand(ByteCityHandle handle, float* res, float* com, float* ind);

// City Evaluation & Approval
int bytecity_get_city_yes(ByteCityHandle handle); // 0 to 100% approval
int bytecity_get_city_no(ByteCityHandle handle);

// Disasters
void bytecity_trigger_disaster(ByteCityHandle handle, int disaster_id);

// Advisor message queue
bool bytecity_has_message(ByteCityHandle handle);
const char* bytecity_pop_message(ByteCityHandle handle);

// File I/O, Scenarios & Options
bool bytecity_load_city(ByteCityHandle handle, const char* filepath);
bool bytecity_save_city(ByteCityHandle handle, const char* filepath);
void bytecity_set_game_level(ByteCityHandle handle, int level);
int bytecity_get_game_level(ByteCityHandle handle);
void bytecity_set_auto_bulldoze(ByteCityHandle handle, bool val);
bool bytecity_get_auto_bulldoze(ByteCityHandle handle);
void bytecity_set_auto_budget(ByteCityHandle handle, bool val);
bool bytecity_get_auto_budget(ByteCityHandle handle);
void bytecity_set_city_name(ByteCityHandle handle, const char* name);
const char* bytecity_get_city_name(ByteCityHandle handle);

// Active Simulation Sprites (Trains, Helicopters, Ships, Disasters)
typedef struct {
    int type;      // 1=TRAIN, 2=HELICOPTER, 3=AIRPLANE, 4=SHIP, 5=MONSTER, 6=TORNADO, 7=EXPLOSION
    int frame;
    int x;         // pixel coordinate (x / 16 gives tile coordinate)
    int y;
    int dir;
} ByteCitySprite;

int bytecity_get_sprites(ByteCityHandle handle, ByteCitySprite* out_sprites, int max_sprites);

// Budget & Funding
void bytecity_get_budget(ByteCityHandle handle,
                         int64_t* tax_fund,
                         int64_t* road_fund, int64_t* road_spend,
                         int64_t* police_fund, int64_t* police_spend,
                         int64_t* fire_fund, int64_t* fire_spend);

void bytecity_set_budget(ByteCityHandle handle, int tax_rate,
                         float road_percent, float police_percent, float fire_percent);

void bytecity_collect_tax(ByteCityHandle handle);

// Query Tile Information
void bytecity_query_tile(ByteCityHandle handle, int x, int y,
                         int* tile_id, int* zone_type, int* land_val,
                         int* crime_val, int* poll_val, bool* powered, bool* road_connected);

// Map Overlays (0=Normal, 1=Power, 2=Pollution, 3=Crime, 4=LandValue, 5=Traffic)
void bytecity_get_overlay_map(ByteCityHandle handle, int overlay_type, uint8_t* out_buffer);

#ifdef __cplusplus
}
#endif

#endif // MICROPOLIS_C_API_H
