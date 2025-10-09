#[compute]
#version 450

const float PI = 3.141592653589793238462643383279502884197169399;
const float EPSILON = 0.00001;
// Invocations in the (x, y, z) dimension
layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;



struct Sheep{
    //changing values
    vec3 position;
    vec3 velocity;
    vec3 acceleration;

    float stress;
    float fear;
    float contagion;

    //constant values
    float courage;

    float view_distance;
    float fear_distance;
    float max_speed;
    float max_speed_afraid;
    float drag;

    int neighbor_count;
};

struct Predator{
    vec3 position;
};

layout(set = 0, binding = 0, std430) restrict buffer HerdBuffer {
    Sheep sheep[];
} herd;


layout(set = 0, binding = 1, std430) restrict buffer PackBuffer {
    Predator predator[];
} pack;

layout(set = 0, binding = 2) restrict buffer Sizes {
    int herd;
    int pack;
} sizes;


layout(push_constant, std430) uniform Params{
    // Herding Parameters
    float neighbor_radius;
    float cohesion_mult;            // Cf
    float alignment_mult;           // Af
    float seperation_mult;          // Sf

    float predator_fear_mult;       // Eef
    float contagion_mult;

    // Panicked Multipliers
    float cohesion_afraid_mult;   // Cef
    float alignment_afraid_mult;  // Aef
    float seperation_afraid_mult; // Sef
} params;



float emotional_stress(float d, float r, float m){
    return atan((r - d), m) / PI + .5;
}

// float inv_sqr(float x, float s){
// 	return pow(s/(x + EPSILON), 2.);
//}

//Implementing Sheep Boids based on this paper here:
//https://www.diva-portal.org/smash/get/diva2:1354921/FULLTEXT01.pdf

void main(){
    uint boid_id = gl_GlobalInvocationID.x;
    if( boid_id >= sizes.herd)
        return;

    Sheep self = herd.sheep[boid_id];
    
    float max_predator_stress = 0.;
    vec3 escape_vector = vec3(0.);
    vec3 alignment_vector = vec3(0.);
    vec3 cohesion_vector = vec3(0.);
    vec3 neighbor_average = vec3(0.);
    vec3 seperation_vector = vec3(0.);
    self.contagion = 0.;

    for(uint i = 0; i < sizes.herd; i++){
        
        
        if(boid_id == i) continue;

        //Escape
        Sheep other = herd.sheep[i];

        //Alignment, Cohesion, and Contagion 

        if(distance(self.position, other.position) < self.view_distance){
            self.neighbor_count++;
            alignment_vector += other.velocity;
            neighbor_average += other.position;
            self.contagion += other.fear;
        }
        

        //Seperation
        vec3 seperation = -(other.position - self.position);
        float dist = length(seperation);
        if(dist < params.neighbor_radius)
			seperation_vector += (params.neighbor_radius - dist)/(dist+EPSILON) * seperation;
    }

    for(uint j = 0; j < sizes.pack; j++){
        Predator p = pack.predator[j];
        float dist = distance(self.position, p.position);
        if(dist < self.fear_distance){
            vec3 escape = self.position - p.position;
            float stress = emotional_stress(dist, self.fear_distance, self.courage);
            escape_vector += stress * normalize(escape);
            max_predator_stress = max(max_predator_stress, stress);
        }
    }

    self.neighbor_count = max(1, self.neighbor_count);

    neighbor_average /= self.neighbor_count;
    alignment_vector /= self.neighbor_count;
    alignment_vector -= self.velocity;
    self.contagion /= self.neighbor_count;

    cohesion_vector = neighbor_average - self.position;

	self.fear = params.predator_fear_mult * max_predator_stress + params.contagion_mult * self.contagion;
	
	vec3 a = vec3(0.);
	vec3 cohesion = params.cohesion_mult * (1. + self.fear * params.cohesion_afraid_mult) * cohesion_vector;
	vec3 alignment = params.alignment_mult * (1. + self.fear * params.alignment_afraid_mult) * alignment_vector;
	vec3 seperation = params.seperation_mult * (1. + self.fear * params.seperation_afraid_mult) * seperation_vector;
	vec3 evasion = self.fear * escape_vector; //ES calc is done inside escape_rule because of per predator
	
	a = (cohesion + alignment + seperation + evasion);
	a = normalize(a) * min(length(a),  (1. + self.fear * self.max_speed_afraid) * self.max_speed);;
    self.acceleration = a;

    herd.sheep[boid_id] = self;
}

