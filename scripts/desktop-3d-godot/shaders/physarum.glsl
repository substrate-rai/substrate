#[compute]
#version 450

// Physarum / Slime Mold — agent-based GPU simulation
// Agents have position + heading, deposit pheromone on trail map
// Trail map diffuses + decays each frame

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// Agent buffer: vec4(pos_x, pos_y, heading, speed)
layout(set = 0, binding = 0, std430) restrict buffer AgentBuffer {
    vec4 agents[];
};

// Trail map: single channel float per pixel
layout(set = 0, binding = 1, r32f) uniform restrict image2D trail_map;

// Parameters pushed as push constants
layout(push_constant, std430) uniform Params {
    float time;
    float delta;
    float sensor_angle;    // radians, ~0.5
    float sensor_dist;     // pixels, ~9.0
    float turn_speed;      // radians/sec, ~2.0
    float deposit_amount;  // ~5.0
    float decay_rate;      // ~0.95
    float diffuse_rate;    // ~0.5
    uint agent_count;
    uint map_width;
    uint map_height;
    float system_load;     // drives agent density
    float audio_bass;      // deposit strength
    float beat_intensity;  // spawn burst
} params;

// Hash for randomness
float hash(uint n) {
    n = (n << 13u) ^ n;
    n = n * (n * n * 15731u + 789221u) + 1376312589u;
    return float(n & 0x7fffffffu) / float(0x7fffffff);
}

float sense(vec4 agent, float angle_offset) {
    float a = agent.z + angle_offset;
    vec2 sense_pos = agent.xy + vec2(cos(a), sin(a)) * params.sensor_dist;

    // Wrap
    ivec2 coord = ivec2(mod(sense_pos, vec2(float(params.map_width), float(params.map_height))));
    return imageLoad(trail_map, coord).r;
}

void main() {
    uint id = gl_GlobalInvocationID.x;
    if (id >= params.agent_count) return;

    vec4 agent = agents[id];
    float heading = agent.z;

    // Sense: left, center, right
    float sense_l = sense(agent, params.sensor_angle);
    float sense_c = sense(agent, 0.0);
    float sense_r = sense(agent, -params.sensor_angle);

    // Steer toward strongest pheromone
    float turn = params.turn_speed * params.delta;

    // Add randomness
    float rand = hash(id + uint(params.time * 1000.0)) * 0.5 - 0.25;
    turn += rand * 0.3;

    if (sense_c > sense_l && sense_c > sense_r) {
        // Go straight
    } else if (sense_l > sense_r) {
        heading += turn;
    } else if (sense_r > sense_l) {
        heading -= turn;
    } else {
        // Random turn when equal
        heading += (hash(id * 3u + uint(params.time * 500.0)) - 0.5) * turn;
    }

    // Move
    float speed = agent.w * (1.0 + params.audio_bass * 0.5);
    vec2 new_pos = agent.xy + vec2(cos(heading), sin(heading)) * speed * params.delta * 60.0;

    // Wrap around
    new_pos = mod(new_pos, vec2(float(params.map_width), float(params.map_height)));

    // Deposit pheromone
    float deposit = params.deposit_amount * (1.0 + params.audio_bass * 2.0);
    if (params.beat_intensity > 0.3) {
        deposit *= 2.0;
    }
    ivec2 pixel = ivec2(new_pos);
    float current = imageLoad(trail_map, pixel).r;
    imageStore(trail_map, pixel, vec4(min(current + deposit * params.delta, 1.0)));

    // Store updated agent
    agents[id] = vec4(new_pos, heading, agent.w);
}
