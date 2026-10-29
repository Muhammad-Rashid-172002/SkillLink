// Storage security-rules checks against local emulators only: ./run_storage.sh
import {initializeApp} from "firebase/app";
import {getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signOut} from "firebase/auth";
import {getStorage, connectStorageEmulator, ref, uploadBytes} from "firebase/storage";
const P="demo-skillnova-rules";
const F=`http://${process.env.FIRESTORE_EMULATOR_HOST}`;
async function seed(path,fields){await fetch(`${F}/v1/projects/${P}/databases/(default)/documents/${path}`,{method:"PATCH",headers:{authorization:"Bearer owner","content-type":"application/json"},body:JSON.stringify({fields})});}
function client(name){const app=initializeApp({projectId:P,apiKey:"x",storageBucket:`${P}.appspot.com`},name);const auth=getAuth(app);connectAuthEmulator(auth,`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`,{disableWarnings:true});const st=getStorage(app);connectStorageEmulator(st,"127.0.0.1",Number(process.env.FIREBASE_STORAGE_EMULATOR_HOST.split(":")[1]));return {auth,st};}
const A=client("a"), B=client("b");
const ua=(await createUserWithEmailAndPassword(A.auth,`a${Date.now()}@t.t`,"Passw0rd!!")).user;
await createUserWithEmailAndPassword(B.auth,`b${Date.now()}@t.t`,"Passw0rd!!");
async function up(c,path,type="image/jpeg"){try{await uploadBytes(ref(c.st,path),new Uint8Array([1,2,3,4]),{contentType:type});return 200;}catch(e){return e.code==="storage/unauthorized"?403:e.code;}}
await seed("chats/c1",{customerId:{stringValue:ua.uid},workerId:{stringValue:"w"}});
const res=[
 ["own worker photo", await up(A,`profile_images/workers/${ua.uid}/profile.jpg`),200],
 ["other worker photo", await up(B,`profile_images/workers/${ua.uid}/profile.jpg`),403],
 ["non-image as photo", await up(A,`profile_images/workers/${ua.uid}/x.bin`,"application/octet-stream"),403],
 ["own customer photo", await up(A,`customer_profiles/${ua.uid}.jpg`),200],
 ["other customer photo", await up(B,`customer_profiles/${ua.uid}.jpg`),403],
 ["own request image", await up(A,`request_images/${ua.uid}/r1/1.jpg`),200],
 ["chat participant media", await up(A,`chat_media/c1/1.jpg`),200],
 ["chat participant audio", await up(A,`chat_audio/c1/1.m4a`,"audio/mp4"),200],
 ["non participant media", await up(B,`chat_media/c1/1.jpg`),403],
 ["own verification", await up(A,`private_verifications/workers/${ua.uid}/cnic.jpg`),200],
 ["someone else's verification", await up(B,`private_verifications/workers/${ua.uid}/cnic.jpg`),403],
 ["receipt upload blocked", await up(A,`payment_receipts/${ua.uid}/r.jpg`),403],
 ["unknown path blocked", await up(A,`random/x.jpg`),403],
];
let fail=0; for(const [n,got,exp] of res){const ok=got===exp; if(!ok)fail++; console.log(ok?"ok":"FAIL",n,got);}
process.exit(fail?1:0);
